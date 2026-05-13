import AVFoundation
import SwiftUI

enum Lens: String, CaseIterable, Identifiable, Sendable {
    case ultraWide
    case wide
    case telephoto

    var id: String { rawValue }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide:      return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        }
    }

    var displayLabel: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide:      return "1×"
        case .telephoto: return "3×"
        }
    }

    func dynamicLabel(zoomFactor: Double?) -> String {
        guard let z = zoomFactor else { return displayLabel }
        return Self.formatZoom(z)
    }

    static func formatZoom(_ zoom: Double) -> String {
        if zoom < 1.0 {
            return String(format: "%.1f×", zoom)
        }
        if abs(zoom - zoom.rounded()) < 0.05 {
            return "\(Int(zoom.rounded()))×"
        }
        return String(format: "%.1f×", zoom)
    }

    static func from(deviceType: AVCaptureDevice.DeviceType) -> Lens? {
        switch deviceType {
        case .builtInUltraWideCamera: return .ultraWide
        case .builtInWideAngleCamera: return .wide
        case .builtInTelephotoCamera: return .telephoto
        default: return nil
        }
    }

    var longName: String {
        switch self {
        case .ultraWide: return String(localized: "Ultra Wide")
        case .wide:      return String(localized: "Main")
        case .telephoto: return String(localized: "Telephoto")
        }
    }
}

enum PhotoFormat: String, CaseIterable, Identifiable, Sendable {
    case heif
    case raw
    case rawPlusHEIF

    var id: String { rawValue }

    var displayLabel: String {
        fullLabel
    }

    var shortLabel: String {
        switch self {
        case .heif:        return "HEIF"
        case .raw:         return "RAW"
        case .rawPlusHEIF: return "R+H"
        }
    }

    var fullLabel: String {
        switch self {
        case .heif:        return "HEIF"
        case .raw:         return "RAW"
        case .rawPlusHEIF: return "RAW+HEIF"
        }
    }
}

enum FlashMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case auto
    case on

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .on:   return "bolt.fill"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .off:  return "Off"
        case .auto: return "Auto"
        case .on:   return "On"
        }
    }

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:  return .off
        case .auto: return .auto
        case .on:   return .on
        }
    }

    func next() -> FlashMode {
        switch self {
        case .off:  return .auto
        case .auto: return .on
        case .on:   return .off
        }
    }
}
