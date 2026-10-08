import AppKit
import Combine
import CoreImage
@preconcurrency import CoreVideo
import ImageIO
import Metal
import Vision

struct ProcessingSnapshot {
    var status = "Original video"
    var ready = false
    var active = false
    var milliseconds = 0.0
    var framesPerSecond = 0.0
    var memoryMB = 0.0
    var frames = 0
    var image: CGImage?

    mutating func clearFrame(status: String) {
        image = nil
        milliseconds = 0
        framesPerSecond = 0
        self.status = status
    }
}

// AVFoundation's delivered buffer is retained, read-only, and handed to exactly
// one worker. No mutation or simultaneous inference accesses it.
private struct CapturedFrame: @unchecked Sendable { let buffer: CVPixelBuffer }

struct ProcessingDebugOptions {
    var faceIdentity = true
    var headHair = true
    var temporal = true
}

final class FrameProcessor: ObservableObject {
    @Published private(set) var snapshot = ProcessingSnapshot()
    private let queue = DispatchQueue(label: "dev.vero2002.aiavatar.neural", qos: .userInitiated)
    private let gate = FrameGate()
    private let context: CIContext
    private let headHair: HeadHairProcessor
    private let debug: ProcessingDebugOptions
    private var client: FaceIdentityProcessor?
    private var state = ProcessingSnapshot()
    private var resetMotion = true
    private var lastFaceTime: TimeInterval = 0
    private var lastFace: CGRect?
    private var lastFrameTime: TimeInterval = 0

    static var identityFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AIAvatar/Identity", isDirectory: true)
    }

    init(debug: ProcessingDebugOptions = ProcessingDebugOptions()) {
        self.debug = debug
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        } else { context = CIContext(options: [.cacheIntermediates: false]) }
        headHair = HeadHairProcessor(context: context)
        headHair.enabled = debug.headHair
    }

    func prepare() { queue.async { [weak self] in self?.initialize() } }

    func importReference(_ url: URL) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let folder = Self.identityFolder
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let bytes = try Data(contentsOf: url)
                _ = try canonicalReference(data: bytes)
                try bytes.write(to: folder.appendingPathComponent("reference.jpg"), options: .atomic)
                initialize()
            } catch { fail(error.localizedDescription) }
        }
    }

    func setEnabled(_ value: Bool) {
        gate.setEnabled(value)
        queue.async { [weak self] in
            guard let self else { return }
            resetMotion = true
            state.active = value && state.ready
            lastFrameTime = 0
            state.clearFrame(status: value && state.ready ? "Waiting for a complete head" : "Original video")
            publish()
        }
    }

    func reset() {
        gate.invalidate()
        queue.async { [weak self] in
            guard let self else { return }
            resetMotion = true
            lastFace = nil
            lastFaceTime = 0
            lastFrameTime = 0
            state.clearFrame(status: "Original video")
            publish()
        }
    }

    func submit(_ buffer: CVPixelBuffer, at time: TimeInterval) {
        guard let epoch = gate.begin() else { return }
        let frame = CapturedFrame(buffer: buffer)
        queue.async { [weak self] in
            guard let self else { return }
            defer { gate.finish() }
            autoreleasepool { self.process(frame.buffer, at: time, epoch: epoch) }
        }
    }

    private func initialize() {
        gate.invalidate()
        resetMotion = true
        lastFace = nil
        lastFaceTime = 0
        lastFrameTime = 0
        state.clearFrame(status: "Loading neural identity")
        state.frames = 0
        state.memoryMB = 0
        client?.shutdown()
        client = nil
        state.ready = false
        state.active = false
        state.status = "Loading neural identity"
        publish()
        do {
            guard debug.faceIdentity else { throw NeuralError.failure("Identity disabled for internal debugging") }
            let runtime = try NeuralRuntime.load()
            let reference = Self.identityFolder.appendingPathComponent("reference.jpg")
            guard FileManager.default.fileExists(atPath: reference.path) else { throw NeuralError.failure("Fixed identity photo required") }
            let image = try canonicalReference(data: Data(contentsOf: reference))
            let cropURL = Self.identityFolder.appendingPathComponent("head-crop.png")
            guard let output = CGImageDestinationCreateWithURL(cropURL as CFURL, "public.png" as CFString, 1, nil) else { throw NeuralError.failure("Could not save private identity crop") }
            CGImageDestinationAddImage(output, image, nil)
            guard CGImageDestinationFinalize(output) else { throw NeuralError.failure("Could not save identity") }
            client = try FaceIdentityProcessor(runtime: runtime, source: cropURL, temporal: debug.temporal)
            state.ready = true
            gate.setEnabled(true)
            state.active = true
            state.status = "Neural identity ready"
            resetMotion = true
            publish()
        } catch { fail(error.localizedDescription) }
    }

    private func canonicalReference(data: Data) throws -> CGImage {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
              let bitmap = context.createCGImage(image, from: image.extent) else { throw NeuralError.failure("Cannot decode reference photo") }
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: bitmap).perform([request])
        guard let faces = request.results, faces.count == 1,
              let crop = HeadGeometry.crop(face: faces[0].boundingBox, image: image.extent.size, allowPadding: true),
              let result = context.createCGImage(resize(image.composited(over: CIImage(color: .black).cropped(to: crop)).cropped(to: crop), to: 512), from: CGRect(x: 0, y: 0, width: 512, height: 512)) else {
            throw NeuralError.failure("Reference must show one complete face and hairstyle")
        }
        return result
    }

    private func process(_ buffer: CVPixelBuffer, at time: TimeInterval, epoch: Int) {
        guard let client, state.ready, isCurrent(epoch) else { return }
        let start = ProcessInfo.processInfo.systemUptime
        do {
            let original = CIImage(cvPixelBuffer: buffer)
            let request = VNDetectFaceLandmarksRequest()
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([request])
            if request.results?.isEmpty != false {
                // Detection-only exposure lift for backlit faces. Camera pixels
                // and the model input retain their actual texture and lighting.
                let lifted = original.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 1.5])
                    .transformed(by: CGAffineTransform(scaleX: 640 / original.extent.width, y: 640 / original.extent.width))
                if let image = context.createCGImage(lifted, from: lifted.extent) {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                }
            }
            guard let faces = request.results, faces.count == 1 else {
                resetMotion = true
                lastFrameTime = 0
                state.clearFrame(status: "Original video: face not tracked")
                publish(epoch: epoch)
                return
            }
            guard let crop = HeadGeometry.crop(face: faces[0].boundingBox, image: original.extent.size, allowPadding: true) else {
                resetMotion = true
                lastFrameTime = 0
                state.clearFrame(status: "Original video: head outside frame")
                publish(epoch: epoch)
                return
            }
            let face = faces[0].boundingBox
            if time - lastFaceTime > 3 || lastFace.map({ abs($0.midX - face.midX) + abs($0.midY - face.midY) > 0.15 }) == true { resetMotion = true }
            lastFace = face
            lastFaceTime = time
            let driving = resize(original.composited(over: CIImage(color: .black).cropped(to: crop)).cropped(to: crop), to: 256)
            var rgba = Data(count: 256 * 256 * 4)
            rgba.withUnsafeMutableBytes { bytes in
                context.render(driving, toBitmap: bytes.baseAddress!, rowBytes: 256 * 4,
                               bounds: CGRect(x: 0, y: 0, width: 256, height: 256), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            var packed = Data(count: 256 * 256 * 3)
            packed.withUnsafeMutableBytes { destination in
                rgba.withUnsafeBytes { source in
                    let src = source.bindMemory(to: UInt8.self), dst = destination.bindMemory(to: UInt8.self)
                    for i in 0..<256 * 256 { for c in 0..<3 { dst[i * 3 + c] = src[i * 4 + c] } }
                }
            }
            let (reply, pixels) = try client.render(rgb: packed, reset: resetMotion)
            resetMotion = false
            guard isCurrent(epoch) else { return }
            let target = CGRect(x: face.minX * original.extent.width, y: face.minY * original.extent.height,
                                width: face.width * original.extent.width, height: face.height * original.extent.height)
            do { state.image = try headHair.composite(pixels, on: original, targetFace: target,
                                                    targetEyes: HeadHairProcessor.eyes(faces[0], image: original.extent.size)) }
            catch {
                resetMotion = true
                lastFrameTime = 0
                state.clearFrame(status: "Original video: \(error.localizedDescription)")
                publish(epoch: epoch)
                return
            }
            state.status = debug.headHair ? "Neural face + head" : "Original video: composition disabled for debugging"
            state.milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
            let finished = ProcessInfo.processInfo.systemUptime
            state.framesPerSecond = lastFrameTime > 0 ? 1 / (finished - lastFrameTime) : 0
            lastFrameTime = finished
            state.memoryMB = reply.peakMemoryMB ?? 0
            state.frames += 1
            publish(epoch: epoch)
        } catch { if isCurrent(epoch) { fail(error.localizedDescription) } }
    }

    private func resize(_ image: CIImage, to size: CGFloat) -> CIImage {
        image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
            .transformed(by: CGAffineTransform(scaleX: size / image.extent.width, y: size / image.extent.height))
    }

    private func fail(_ message: String) {
        client?.shutdown(); client = nil
        gate.setEnabled(false)
        state.ready = false; state.active = false
        lastFrameTime = 0
        state.clearFrame(status: message)
        publish()
    }

    private func isCurrent(_ epoch: Int) -> Bool {
        gate.isCurrent(epoch)
    }

    private func publish(epoch: Int? = nil) {
        let value = state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard epoch.map({ self.isCurrent($0) }) ?? true else { return }
            snapshot = value
        }
    }
}
