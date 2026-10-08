import CoreImage
import CoreVideo
import Vision

final class HeadHairProcessor {
    private let context: CIContext
    private let segmentation = VNGeneratePersonSegmentationRequest()
    private let faceDetection = VNDetectFaceLandmarksRequest()
    var enabled = true // Internal debug switch; never an avatar selector.

    init(context: CIContext) {
        self.context = context
        segmentation.qualityLevel = .balanced
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    static func eyes(_ face: VNFaceObservation, image: CGSize) -> FaceEyes? {
        func center(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let region, region.pointCount > 0 else { return nil }
            var point = CGPoint.zero
            for i in 0..<region.pointCount {
                point.x += CGFloat(region.normalizedPoints[i].x)
                point.y += CGFloat(region.normalizedPoints[i].y)
            }
            point.x /= CGFloat(region.pointCount)
            point.y /= CGFloat(region.pointCount)
            return CGPoint(x: (face.boundingBox.minX + point.x * face.boundingBox.width) * image.width,
                           y: (face.boundingBox.minY + point.y * face.boundingBox.height) * image.height)
        }
        guard let left = center(face.landmarks?.leftEye), let right = center(face.landmarks?.rightEye),
              hypot(left.x - right.x, left.y - right.y) > face.boundingBox.width * image.width * 0.15 else { return nil }
        return FaceEyes(left: left, right: right)
    }

    func composite(_ pixels: Data, on original: CIImage, targetFace: CGRect, targetEyes: FaceEyes? = nil) throws -> CGImage {
        if !enabled, let result = context.createCGImage(original, from: original.extent) { return result }
        guard pixels.count == 512 * 512 * 3, let provider = CGDataProvider(data: pixels as CFData),
              let bitmap = CGImage(width: 512, height: 512, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: 512 * 3,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: [], provider: provider,
                                   decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw NeuralError.failure("Cannot decode neural pixels") }
        try VNImageRequestHandler(cgImage: bitmap).perform([segmentation, faceDetection])
        guard let maskBuffer = segmentation.results?.first?.pixelBuffer else { throw NeuralError.failure("Head segmentation unavailable") }
        guard let observations = faceDetection.results, observations.count == 1 else { throw NeuralError.failure("Generated face cannot be aligned") }
        let observation = observations[0]
        let face = observation.boundingBox
        let generatedFace = CGRect(x: face.minX * 512, y: face.minY * 512, width: face.width * 512, height: face.height * 512)
        let eyeTransform: CGAffineTransform?
        if let generatedEyes = Self.eyes(observation, image: CGSize(width: 512, height: 512)), let targetEyes {
            eyeTransform = HeadGeometry.placement(generated: generatedEyes, target: targetEyes)
        } else { eyeTransform = nil }
        guard let transform = eyeTransform ?? HeadGeometry.placement(generated: generatedFace, target: targetFace) else {
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
