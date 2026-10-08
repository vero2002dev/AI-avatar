import XCTest
@testable import AIAvatar

final class HeadGeometryTests: XCTestCase {
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
