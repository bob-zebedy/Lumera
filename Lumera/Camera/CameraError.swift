import Foundation

struct CameraOperationTimeout: LocalizedError {
    enum Operation {
        case capture
        case save
    }
    let operation: Operation
    var errorDescription: String? {
        switch operation {
        case .capture: return String(localized: "Photo capture timed out")
        case .save:    return String(localized: "Saving to Photos timed out")
        }
    }

    static func run<T: Sendable>(
        seconds: TimeInterval,
        as operation: Operation,
        body: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CameraOperationTimeout(operation: operation)
            }
            guard let first = try await group.next() else {
                throw CameraOperationTimeout(operation: operation)
            }
            group.cancelAll()
            return first
        }
    }
}

enum CameraError: LocalizedError {
    case cameraUnauthorized
    case photoLibraryUnauthorized
    case noDeviceAvailable
    case cannotAddInput
    case cannotAddOutput
    case configurationFailed
    case captureFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .cameraUnauthorized:
            return nil
        case .photoLibraryUnauthorized:
            return String(localized: "Photo library access denied")
        case .noDeviceAvailable:
            return String(localized: "No matching camera found")
        case .cannotAddInput:
            return String(localized: "Camera is busy")
        case .cannotAddOutput:
            return String(localized: "Cannot save photo")
        case .configurationFailed:
            return String(localized: "Configuration error")
        case .captureFailed(let underlying):
            let detail = underlying?.localizedDescription ?? String(localized: "unknown error")
            return String(localized: "Capture failed: \(detail)")
        }
    }
}
