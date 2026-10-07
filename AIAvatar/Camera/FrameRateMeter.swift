import Foundation

struct CaptureMetrics: Equatable, Sendable {
    var width = 0
    var height = 0
    var framesPerSecond: Double = 0
    var droppedFrames = 0
}

struct FrameRateMeter {
    private var windowStart: TimeInterval?
    private var frameCount = 0
    private var droppedFrames = 0

    mutating func recordDrop() {
        droppedFrames += 1
    }

    mutating func recordFrame(at time: TimeInterval, width: Int, height: Int) -> CaptureMetrics? {
        guard let start = windowStart else {
            windowStart = time
            frameCount = 0
            return CaptureMetrics(width: width, height: height, droppedFrames: droppedFrames)
        }
        frameCount += 1
        let elapsed = time - start
        guard elapsed >= 1 else { return nil }
        let metrics = CaptureMetrics(
            width: width,
            height: height,
            framesPerSecond: Double(frameCount) / elapsed,
            droppedFrames: droppedFrames
        )
        windowStart = time
        frameCount = 0
        return metrics
    }

    mutating func reset() {
        self = FrameRateMeter()
    }
}
