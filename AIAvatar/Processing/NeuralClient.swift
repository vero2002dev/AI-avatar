import Foundation

struct NeuralRuntime {
    let root: URL
    var python: URL { root.appendingPathComponent("python/bin/python3") }
    var engine: URL { root.appendingPathComponent("engine") }
    var weights: URL { root.appendingPathComponent("weights/liveportrait_mlx") }
    var worker: URL { root.appendingPathComponent("worker.py") }

    static func load() throws -> NeuralRuntime {
        guard #available(macOS 15.0, *) else { throw NeuralError.failure("Neural runtime requires macOS 15+") }
#if !arch(arm64)
        throw NeuralError.failure("Neural runtime requires Apple Silicon")
#else
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("Neural"),
              FileManager.default.isExecutableFile(atPath: root.appendingPathComponent("python/bin/python3").path) else {
            throw NeuralError.failure("Neural runtime not installed")
        }
        return Self(root: root)
#endif
    }
}

enum NeuralError: LocalizedError {
    case failure(String)
    var errorDescription: String? { if case .failure(let text) = self { return text }; return nil }
}

// The timeout queue terminates a blocked helper. Capture callbacks never wait
// on a pipe. The bundled interpreter inherits the app sandbox.
final class FaceIdentityProcessor {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var watchdog: DispatchSourceTimer?
    private var frameID = 0

    init(runtime: NeuralRuntime, source: URL, temporal: Bool = true) throws {
        process.executableURL = runtime.python
        process.arguments = [runtime.worker.path, "--engine", runtime.engine.path, "--weights", runtime.weights.path, "--source", source.path]
        if !temporal { process.arguments?.append("--no-temporal") }
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.standardError
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HUB_OFFLINE"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONHOME"] = runtime.root.appendingPathComponent("python").path
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = environment
        try process.run()
        armTimeout(seconds: 120)
        defer { watchdog?.cancel() }
        let (header, _) = try receive()
        guard header.type == "ready", header.bytes == 0 else {
            shutdown()
            throw NeuralError.failure(header.message ?? "Neural engine could not initialize")
        }
    }

    deinit { shutdown() }

    func render(rgb: Data, reset: Bool) throws -> (NeuralReply, Data) {
        guard rgb.count == 256 * 256 * 3, process.isRunning else { throw NeuralError.failure("Neural engine stopped") }
        frameID += 1
        armTimeout(seconds: 15)
        defer { watchdog?.cancel() }
        let json = try JSONSerialization.data(withJSONObject: ["type": "frame", "id": frameID, "bytes": rgb.count, "reset": reset])
        var size = UInt32(json.count).littleEndian
        var packet = withUnsafeBytes(of: &size) { Data($0) }
        packet.append(json)
        packet.append(rgb)
        try input.fileHandleForWriting.write(contentsOf: packet)
        let (reply, payload) = try receive()
        guard reply.isValidFrame, reply.id == frameID else { throw NeuralError.failure(reply.message ?? "Invalid neural frame") }
        return (reply, payload)
    }

    func shutdown() {
        watchdog?.cancel()
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }

    private func armTimeout(seconds: Double) {
        watchdog?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + seconds)
        timer.setEventHandler { [weak process] in
            if let process, process.isRunning { process.terminate() }
        }
        timer.resume()
        watchdog = timer
    }

    private func receive() throws -> (NeuralReply, Data) {
        let prefix = try readExactly(4)
        let length = prefix.withUnsafeBytes { Int($0.loadUnaligned(as: UInt32.self).littleEndian) }
        guard (1...4096).contains(length) else { throw NeuralError.failure("Invalid neural packet length") }
        let header = try JSONDecoder().decode(NeuralReply.self, from: readExactly(length))
        guard (0...512 * 512 * 3).contains(header.bytes) else { throw NeuralError.failure("Invalid neural payload length") }
        return (header, try readExactly(header.bytes))
    }

    private func readExactly(_ count: Int) throws -> Data {
        var result = Data()
        while result.count < count {
            guard let chunk = try output.fileHandleForReading.read(upToCount: count - result.count), !chunk.isEmpty else {
                throw NeuralError.failure("Neural engine disconnected or timed out")
            }
            result.append(chunk)
        }
        return result
    }
}
