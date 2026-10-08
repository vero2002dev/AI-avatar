import CoreImage
import Foundation
import ImageIO
import Vision

// Offline neural validation only; never captures a camera or uploads a photo.
@main
struct ReferenceCrop {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 3, let image = CIImage(contentsOf: URL(fileURLWithPath: args[1]), options: [.applyOrientationProperty: true]) else {
            throw NSError(domain: "ReferenceCrop", code: 1)
        }
        let context = CIContext()
        let bitmap = context.createCGImage(image, from: image.extent)!
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: bitmap).perform([request])
        guard let face = request.results?.first else { throw NSError(domain: "NoFace", code: 1) }
        print("Face: \(face.boundingBox), image: \(image.extent)")
        guard let crop = HeadGeometry.crop(face: face.boundingBox, image: image.extent.size, allowPadding: true) else { throw NSError(domain: "ClippedCrop", code: 1) }
        let cropped = image.composited(over: CIImage(color: .black).cropped(to: crop)).cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: 512 / crop.width, y: 512 / crop.height))
        let result = context.createCGImage(cropped, from: CGRect(x: 0, y: 0, width: 512, height: 512))!
        let target = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(target, result, nil)
        guard CGImageDestinationFinalize(target) else { throw NSError(domain: "CannotSave", code: 1) }
    }
}
