import CoreGraphics
import Foundation

enum HeadGeometry {
    // Vision and Core Image use bottom-left coordinates. Reference and driving
    // crops must share this convention to preserve native scale and translation.
    static func crop(face: CGRect, image: CGSize, allowPadding: Bool = false) -> CGRect? {
        guard face.width.isFinite, face.height.isFinite, face.minX.isFinite, face.minY.isFinite,
              face.width > 0.02, face.height > 0.02, image.width > 0, image.height > 0 else { return nil }
        let pixels = CGRect(x: face.minX * image.width, y: face.minY * image.height,
                            width: face.width * image.width, height: face.height * image.height)
        let side = max(pixels.width * 2.1, pixels.height * 1.85)
        let result = CGRect(x: pixels.midX - side / 2, y: pixels.midY + pixels.height * 0.18 - side / 2,
                            width: side, height: side)
        let bounds = CGRect(origin: .zero, size: image)
        if bounds.contains(result) { return result }
        if allowPadding, bounds.contains(pixels), result.intersection(bounds).width * result.intersection(bounds).height > side * side * 0.65 {
            return result
        }
        return nil
    }
}

struct NeuralReply: Decodable {
    var type: String
    var bytes: Int
    var id: Int?
    var width: Int?
    var height: Int?
    var milliseconds: Double?
    var memoryMB: Double?
    var peakMemoryMB: Double?
    var message: String?

    var isValidFrame: Bool {
        type == "frame" && width == 512 && height == 512 && bytes == 512 * 512 * 3 &&
        milliseconds?.isFinite == true && (milliseconds ?? -1) >= 0
    }
}
