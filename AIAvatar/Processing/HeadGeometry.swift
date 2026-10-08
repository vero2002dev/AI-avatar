import CoreGraphics
import Foundation

enum HeadGeometry {
    static func placement(generated: CGRect, target: CGRect) -> CGAffineTransform? {
        guard generated.width > 0, generated.height > 0, target.width > 0, target.height > 0,
              generated.midX.isFinite, generated.midY.isFinite, target.midX.isFinite, target.midY.isFinite else { return nil }
        let scale = sqrt(target.width / generated.width * target.height / generated.height)
        guard scale.isFinite else { return nil }
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                 tx: target.midX - generated.midX * scale,
                                 ty: target.midY - generated.midY * scale)
    }

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

final class FrameGate: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    private var busy = false
    private var generation = 0

    func setEnabled(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        enabled = value
        generation += 1
    }

    func invalidate() { lock.lock(); generation += 1; lock.unlock() }

    func begin() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard enabled, !busy else { return nil }
        busy = true
        return generation
    }

    func finish() { lock.lock(); busy = false; lock.unlock() }

    func isCurrent(_ epoch: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return enabled && generation == epoch
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
