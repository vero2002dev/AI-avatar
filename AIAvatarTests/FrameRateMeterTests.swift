import XCTest
@testable import AIAvatar

final class FrameRateMeterTests: XCTestCase {
    func testFirstFrameReportsRealDimensionsWithoutInventingFrameRate() {
        var meter = FrameRateMeter()
        let first = meter.recordFrame(at: 10, width: 1280, height: 720)
        XCTAssertEqual(first?.width, 1280)
        XCTAssertEqual(first?.height, 720)
        XCTAssertEqual(first?.framesPerSecond, 0)
    }

    func testMeasuresDeliveredFrameRateAndDroppedFrames() {
        var meter = FrameRateMeter()
        _ = meter.recordFrame(at: 10, width: 1280, height: 720)
        for index in 1..<30 {
            XCTAssertNil(meter.recordFrame(at: 10 + Double(index) / 30, width: 1280, height: 720))
        }
        meter.recordDrop()
        meter.recordDrop()
        let metrics = meter.recordFrame(at: 11, width: 1280, height: 720)
        XCTAssertEqual(metrics?.framesPerSecond, 30)
        XCTAssertEqual(metrics?.droppedFrames, 2)
    }

    func testSlowDeliveryIsMeasuredAgainstElapsedTime() {
        var meter = FrameRateMeter()
        _ = meter.recordFrame(at: 0, width: 640, height: 480)
        let metrics = meter.recordFrame(at: 2, width: 640, height: 480)
        XCTAssertEqual(metrics?.framesPerSecond, 0.5)
    }

    func testSwitchingCameraClearsPreviousMeasurements() {
        var meter = FrameRateMeter()
        _ = meter.recordFrame(at: 0, width: 1280, height: 720)
        meter.recordDrop()
        meter.reset()
        let metrics = meter.recordFrame(at: 50, width: 640, height: 480)
        XCTAssertEqual(metrics?.width, 640)
        XCTAssertEqual(metrics?.droppedFrames, 0)
        XCTAssertEqual(metrics?.framesPerSecond, 0)
    }
}
