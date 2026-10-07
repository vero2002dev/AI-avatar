import AVFoundation
import Foundation

enum CameraKind: String, CaseIterable, Sendable {
    case continuity
    case builtIn
    case external
    case deskView

    var label: String {
        switch self {
        case .continuity: return "iPhone Continuity Camera"
        case .builtIn: return "Mac camera"
        case .external: return "External camera"
        case .deskView: return "Desk View"
        }
    }

    var preference: Int {
        switch self {
        case .continuity: return 0
        case .builtIn: return 1
        case .external: return 2
        case .deskView: return 3
        }
    }
}

struct CameraDevice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: CameraKind

    init(id: String, name: String, kind: CameraKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    init(_ device: AVCaptureDevice) {
        id = device.uniqueID
        name = device.localizedName
        if device.deviceType == .deskViewCamera {
            kind = .deskView
        } else if device.isContinuityCamera || device.deviceType == .continuityCamera {
            kind = .continuity
        } else if device.deviceType == .builtInWideAngleCamera {
            kind = .builtIn
        } else {
            kind = .external
        }
    }

    static func sorted(_ devices: [CameraDevice]) -> [CameraDevice] {
        devices.sorted {
            if $0.kind.preference != $1.kind.preference {
                return $0.kind.preference < $1.kind.preference
            }
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
}

struct CameraSelectionPolicy {
    private(set) var manuallySelectedID: String?

    var isAutomatic: Bool { manuallySelectedID == nil }

    mutating func select(_ id: String) {
        manuallySelectedID = id
    }

    mutating func useAutomaticSelection() {
        manuallySelectedID = nil
    }

    func preferredDevice(in devices: [CameraDevice]) -> CameraDevice? {
        if let id = manuallySelectedID, let selected = devices.first(where: { $0.id == id }) {
            return selected
        }
        return CameraDevice.sorted(devices).first
    }
}
