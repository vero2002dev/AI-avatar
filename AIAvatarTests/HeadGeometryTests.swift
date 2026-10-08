import XCTest
@testable import AIAvatar

final class HeadGeometryTests: XCTestCase {
    func testBackpressureAllowsOnlyOneFlight() throws {
        let gate = FrameGate()
        XCTAssertNil(gate.begin())
        gate.setEnabled(true)
        XCTAssertNotNil(gate.begin())
        XCTAssertNil(gate.begin())
        gate.finish()
        XCTAssertNotNil(gate.begin())
    }

    func testCameraResetRejectsOldGenerationWithoutConcurrentFlight() throws {
        let gate = FrameGate()
        gate.setEnabled(true)
        let old = try XCTUnwrap(gate.begin())
        gate.invalidate()
        XCTAssertFalse(gate.isCurrent(old))
        XCTAssertNil(gate.begin())
        gate.finish()
        let new = try XCTUnwrap(gate.begin())
        XCTAssertTrue(gate.isCurrent(new))
        XCTAssertNotEqual(old, new)
    }

    func testDisablingRejectsPendingOutput() throws {
        let gate = FrameGate()
        gate.setEnabled(true)
        let old = try XCTUnwrap(gate.begin())
        gate.setEnabled(false)
        XCTAssertFalse(gate.isCurrent(old))
        gate.finish()
        XCTAssertNil(gate.begin())
    }

    func testGeneratedFaceMapsToTrackedCenterAndScale() throws {
        let source = CGRect(x: 100, y: 80, width: 180, height: 220)
        let target = CGRect(x: 900, y: 100, width: 360, height: 440)
        let transform = try XCTUnwrap(HeadGeometry.placement(generated: source, target: target))
        let mapped = source.applying(transform)
        XCTAssertEqual(mapped.midX, target.midX, accuracy: 0.001)
        XCTAssertEqual(mapped.midY, target.midY, accuracy: 0.001)
        XCTAssertEqual(mapped.width, target.width, accuracy: 0.001)
        XCTAssertEqual(mapped.height, target.height, accuracy: 0.001)
    }

    func testAlignmentNeverDistortsHeadAspectRatio() throws {
        let source = CGRect(x: 10, y: 10, width: 200, height: 300)
        let target = CGRect(x: 900, y: 100, width: 300, height: 300)
        let transform = try XCTUnwrap(HeadGeometry.placement(generated: source, target: target))
        XCTAssertEqual(transform.a, transform.d)
        XCTAssertEqual(source.applying(transform).midX, target.midX, accuracy: 0.001)
    }

    func testZeroSizeAlignmentRejected() {
        XCTAssertNil(HeadGeometry.placement(generated: .zero, target: CGRect(x: 0, y: 0, width: 10, height: 10)))
    }

    func testCropIsSquareAndIncludesHairAboveFace() throws {
        let face = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let crop = try XCTUnwrap(HeadGeometry.crop(face: face, image: CGSize(width: 1000, height: 1000)))
        XCTAssertEqual(crop.width, crop.height)
        XCTAssertGreaterThan(crop.midY, 500)
        XCTAssertTrue(crop.contains(CGRect(x: 400, y: 400, width: 200, height: 200)))
    }

    func testClippedHeadIsRejected() {
        XCTAssertNil(HeadGeometry.crop(face: CGRect(x: 0.01, y: 0.4, width: 0.3, height: 0.3), image: CGSize(width: 1000, height: 1000)))
    }

    func testNonFiniteCoordinatesAreRejected() {
        XCTAssertNil(HeadGeometry.crop(face: CGRect(x: CGFloat.nan, y: 0.4, width: 0.3, height: 0.3), image: CGSize(width: 1000, height: 1000)))
    }

    func testValidNeuralPacket() throws {
        let data = Data(#"{"type":"frame","bytes":786432,"id":1,"width":512,"height":512,"milliseconds":35}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(NeuralReply.self, from: data).isValidFrame)
    }

    func testWrongNeuralDimensionsAreRejected() throws {
        let data = Data(#"{"type":"frame","bytes":786432,"id":1,"width":1024,"height":512,"milliseconds":35}"#.utf8)
        XCTAssertFalse(try JSONDecoder().decode(NeuralReply.self, from: data).isValidFrame)
    }
}
