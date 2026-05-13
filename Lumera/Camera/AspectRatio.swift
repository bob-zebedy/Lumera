import Foundation
import CoreGraphics

enum AspectRatio: String, CaseIterable, Identifiable, Sendable {
    case fullScreen
    case ratio16x9
    case ratio1x1

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fullScreen: return "FULL"
        case .ratio16x9:  return "16:9"
        case .ratio1x1:   return "1:1"
        }
    }

    func next() -> AspectRatio {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    var widthOverHeight: CGFloat {
        switch self {
        case .fullScreen: return 4.0 / 3.0
        case .ratio16x9:  return 16.0 / 9.0
        case .ratio1x1:   return 1.0
        }
    }

    var croppingProcessedPhoto: Bool {
        switch self {
        case .fullScreen:           return false
        case .ratio16x9, .ratio1x1: return true
        }
    }

    var showsMask: Bool {
        self != .fullScreen
    }
}
