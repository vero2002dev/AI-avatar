import CoreImage
import ImageIO
import Metal
import Vision

// Compile with the production geometry, compositor and neural client sources.
// This exercises real Vision/Metal composition without capturing or uploading.
@main
struct CompositionCheck {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4, let device = MTLCreateSystemDefaultDevice() else {
            throw NeuralError.failure("Expected generated PNG, driving photo, output PNG; Metal required")
        }
        let context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        guard let original = CIImage(contentsOf: URL(fileURLWithPath: arguments[2]), options: [.applyOrientationProperty: true]),
              let generated = CIImage(contentsOf: URL(fileURLWithPath: arguments[1])),
              generated.extent.size == CGSize(width: 512, height: 512),
              let originalBitmap = context.createCGImage(original, from: original.extent) else {
            throw NeuralError.failure("Cannot decode input images; generated head must be 512-square")
        }
        let detection = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: originalBitmap).perform([detection])
        guard let faces = detection.results, faces.count == 1 else { throw NeuralError.failure("Expected one target face") }
        let observation = faces[0], box = observation.boundingBox
        let target = CGRect(x: box.minX * original.extent.width, y: box.minY * original.extent.height,
                            width: box.width * original.extent.width, height: box.height * original.extent.height)
        let rgba = pixels(generated, bounds: generated.extent, context: context)
        var rgb = Data(count: 512 * 512 * 3)
        rgb.withUnsafeMutableBytes { destination in
            let bytes = destination.bindMemory(to: UInt8.self)
            for i in 0..<512 * 512 { for c in 0..<3 { bytes[i * 3 + c] = rgba[i * 4 + c] } }
        }
        let processor = HeadHairProcessor(context: context)
        let output = try processor.composite(rgb, on: original, targetFace: target,
                                            targetEyes: HeadHairProcessor.eyes(observation, image: original.extent.size))
        // Compare below the torso midline. Both paths use identical color handling.
        let body = CGRect(x: original.extent.minX, y: original.extent.minY,
                          width: original.extent.width, height: floor(original.extent.height * 0.4))
        let before = pixels(original, bounds: body, context: context)
        let after = pixels(CIImage(cgImage: output), bounds: body, context: context)
        var maxDifference = 0
        for (before, after) in zip(before, after) {
            maxDifference = max(maxDifference, abs(Int(before) - Int(after)))
        }
        guard maxDifference <= 1 else { throw NeuralError.failure("Body pixels changed: maximum difference \(maxDifference)/255") }
        guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: arguments[3]) as CFURL, "public.png" as CFString, 1, nil) else {
            throw NeuralError.failure("Cannot create output PNG")
        }
        CGImageDestinationAddImage(destination, output, nil)
        guard CGImageDestinationFinalize(destination) else { throw NeuralError.failure("PNG write failed") }
        print("Composited \(output.width)x\(output.height); lower-body maximum pixel difference \(maxDifference)/255")
    }

    private static func pixels(_ image: CIImage, bounds: CGRect, context: CIContext) -> [UInt8] {
        let width = Int(bounds.width), height = Int(bounds.height)
        var result = [UInt8](repeating: 0, count: width * height * 4)
        context.render(image, toBitmap: &result, rowBytes: width * 4,
                       bounds: bounds, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return result
    }
}
