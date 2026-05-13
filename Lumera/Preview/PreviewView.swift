import UIKit
import AVFoundation

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        previewLayer.videoGravity = .resizeAspectFill
    }

    func captureDevicePoint(forViewPoint p: CGPoint) -> CGPoint {
        previewLayer.captureDevicePointConverted(fromLayerPoint: p)
    }

    func viewRect(forMetadataOutputRect rect: CGRect) -> CGRect {
        previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
    }
}
