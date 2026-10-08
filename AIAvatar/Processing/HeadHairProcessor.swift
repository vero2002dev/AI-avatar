import CoreImage
import CoreVideo
import Vision

final class HeadHairProcessor {
    private let context: CIContext
    private let segmentation = VNGeneratePersonSegmentationRequest()
    var enabled = true // Internal debug switch; never an avatar selector.

    init(context: CIContext) {
        self.context = context
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    func composite(_ pixels: Data, on original: CIImage, crop: CGRect) throws -> CGImage {
        if !enabled, let result = context.createCGImage(original, from: original.extent) { return result }
        guard pixels.count == 512 * 512 * 3, let provider = CGDataProvider(data: pixels as CFData),
              let bitmap = CGImage(width: 512, height: 512, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: 512 * 3,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: [], provider: provider,
                                   decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw NeuralError.failure("Cannot decode neural pixels") }
        try VNImageRequestHandler(cgImage: bitmap).perform([segmentation])
        guard let maskBuffer = segmentation.results?.first?.pixelBuffer else { throw NeuralError.failure("Head segmentation unavailable") }
        let head = CIImage(cgImage: bitmap)
        let rawMask = CIImage(cvPixelBuffer: maskBuffer)
        let scaled = rawMask.transformed(by: CGAffineTransform(scaleX: 512 / rawMask.extent.width, y: 512 / rawMask.extent.height))
        // Reject an empty matte instead of reporting an unchanged video as AI.
        let average = scaled.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: scaled.extent)])
        var coverage = [UInt8](repeating: 0, count: 4)
        context.render(average, toBitmap: &coverage, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        guard coverage[0] > 15 else { throw NeuralError.failure("Neural head matte is empty") }
        // Below chin/neck, body and tattoos are always the actual camera pixels.
        let trimmed = scaled.cropped(to: CGRect(x: 0, y: 94, width: 512, height: 418))
        let black = CIImage(color: .black).cropped(to: head.extent)
        let mask = trimmed.composited(over: black).applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0]).cropped(to: head.extent)
        let transform = CGAffineTransform(scaleX: crop.width / 512, y: crop.height / 512)
            .concatenating(CGAffineTransform(translationX: crop.minX, y: crop.minY))
        let positionedMask = mask.transformed(by: transform).composited(over: CIImage(color: .black).cropped(to: original.extent))
        let result = head.transformed(by: transform).applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: original, kCIInputMaskImageKey: positionedMask])
        guard let output = context.createCGImage(result, from: original.extent) else { throw NeuralError.failure("Metal compositing failed") }
        return output
    }
}
