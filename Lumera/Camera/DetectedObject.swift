import AVFoundation
import CoreGraphics
import Foundation

enum DetectionType: String, CaseIterable, Sendable {
    case face

    var metadataObjectType: AVMetadataObject.ObjectType {
        switch self {
        case .face: return .face
        }
    }

    init?(metadataObjectType: AVMetadataObject.ObjectType) {
        switch metadataObjectType {
        case .face: self = .face
        default:    return nil
        }
    }
}

struct DetectedObject: Identifiable, Equatable, Sendable {
    var id: Int
    let type: DetectionType
    let bounds: CGRect

    var area: CGFloat { bounds.width * bounds.height }
    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
}

struct DetectionTrack {
    let id: Int
    let type: DetectionType
    var bounds: CGRect
    var confirmCount: Int
    var lastSeen: Date
}
