import XCTest
@testable import AIAvatar

final class CameraSelectionTests: XCTestCase {
    private let mac = CameraDevice(id: "mac", name: "FaceTime HD Camera", kind: .builtIn)
    private let phone = CameraDevice(id: "phone", name: "iPhone Camera", kind: .continuity)
    private let usb = CameraDevice(id: "usb", name: "USB Camera", kind: .external)
    private let desk = CameraDevice(id: "desk", name: "Desk View", kind: .deskView)

    func testAutomaticSelectionPrefersContinuityCameraRegardlessOfEnumerationOrder() {
        let policy = CameraSelectionPolicy()
        XCTAssertEqual(policy.preferredDevice(in: [usb, mac, phone, desk]), phone)
        XCTAssertEqual(policy.preferredDevice(in: [desk, phone, mac, usb]), phone)
    }

    func testFallbackOrderAndEmptyDiscovery() {
        let policy = CameraSelectionPolicy()
        XCTAssertEqual(policy.preferredDevice(in: [usb, mac, desk]), mac)
        XCTAssertEqual(policy.preferredDevice(in: [desk, usb]), usb)
        XCTAssertNil(policy.preferredDevice(in: []))
    }

    func testConnectingAnIPhoneDoesNotOverrideManualSelection() {
        var policy = CameraSelectionPolicy()
        policy.select(usb.id)
        XCTAssertEqual(policy.preferredDevice(in: [mac, usb]), usb)
        XCTAssertEqual(policy.preferredDevice(in: [phone, mac, usb]), usb)
        XCTAssertFalse(policy.isAutomatic)
    }

    func testDisconnectedManualCameraFallsBackAndReturnsWhenReconnected() {
        var policy = CameraSelectionPolicy()
        policy.select(usb.id)
        XCTAssertEqual(policy.preferredDevice(in: [mac, phone]), phone)
        XCTAssertEqual(policy.manuallySelectedID, usb.id)
        XCTAssertEqual(policy.preferredDevice(in: [mac, phone, usb]), usb)
    }

    func testRestoringAutomaticSelectionClearsManualPreference() {
        var policy = CameraSelectionPolicy()
        policy.select(mac.id)
        policy.useAutomaticSelection()
        XCTAssertTrue(policy.isAutomatic)
        XCTAssertEqual(policy.preferredDevice(in: [mac, phone]), phone)
    }

    func testDuplicateDeviceNamesHaveStableOrder() {
        let first = CameraDevice(id: "a", name: "USB Camera", kind: .external)
        let second = CameraDevice(id: "b", name: "USB Camera", kind: .external)
        XCTAssertEqual(CameraDevice.sorted([second, first]), [first, second])
    }
}
