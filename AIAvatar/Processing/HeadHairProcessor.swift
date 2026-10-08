import CoreImage
import CoreVideo
import Vision

final class HeadHairProcessor {
    private let context: CIContext
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private let faceDetection = VNDetectFaceRectanglesRequest()
    var enabled = true // Internal debug switch; never an avatar selector.

    init(context: CIContext) {
        self.context = context
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    func composite(_ pixels: Data, on original: CIImage, targetFace: CGRect) throws -> CGImage {
        if !enabled, let result = context.createCGImage(original, from: original.extent) { return result }
        guard pixels.count == 512 * 512 * 3, let provider = CGDataProvider(data: pixels as CFData),
              let bitmap = CGImage(width: 512, height: 512, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: 512 * 3,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: [], provider: provider,
                                   decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw NeuralError.failure("Cannot decode neural pixels") }
        try VNImageRequestHandler(cgImage: bitmap).perform([segmentation, faceDetection])
        guard let maskBuffer = segmentation.results?.first?.pixelBuffer else { throw NeuralError.failure("Head segmentation unavailable") }
        guard let face = faceDetection.results?.first?.boundingBox else { throw NeuralError.failure("Generated face cannot be aligned") }
        let generatedFace = CGRect(x: face.minX * 512, y: face.minY * 512, width: face.width * 512, height: face.height * 512)
        guard let transform = HeadGeometry.placement(generated: generatedFace, target: targetFace) else {
            throw NeuralError.failure("Invalid face alignment")
        }
        let head = CIImage(cgImage: bitmap)
        let rawMask = CIImage(cvPixelBuffer: maskBuffer)
        let scaled = rawMask.transformed(by: CGAffineTransform(scaleX: 512 / rawMask.extent.width, y: 512 / rawMask.extent.height))
        // Reject an empty matte instead of reporting an unchanged video as AI.
        let average = scaled.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: scaled.extent)])
        var coverage = [UInt8](repeating: 0, count: 4)
        context.render(average, toBitmap: &coverage, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        guard coverage[0] > 15 else { throw NeuralError.failure("Neural head matte is empty") }
        // Below chin/neck, body and tattoos are always the actual camera pixels.
        let chin = max(0, generatedFace.minY - 6)
        let trimmed = scaled.cropped(to: CGRect(x: 0, y: chin, width: 512, height: 512 - chin))
        let black = CIImage(color: .black).cropped(to: head.extent)
        let mask = trimmed.composited(over: black).applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0]).cropped(to: head.extent)
        let positionedMask = mask.transformed(by: transform).composited(over: CIImage(color: .black).cropped(to: original.extent))
        let result = head.transformed(by: transform).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: original, kCIInputMaskImageKey: positionedMask])
        guard let output = context.createCGImage(result, from: original.extent) else { throw NeuralError.failure("Metal compositing failed") }
        return output
    }
}
