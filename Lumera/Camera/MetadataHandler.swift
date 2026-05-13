import AVFoundation

final class MetadataHandler: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let onObjects: @Sendable ([AVMetadataObject]) -> Void

    init(onObjects: @escaping @Sendable ([AVMetadataObject]) -> Void) {
        self.onObjects = onObjects
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        onObjects(metadataObjects)
    }
}
