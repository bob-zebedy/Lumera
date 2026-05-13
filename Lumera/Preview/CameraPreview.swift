import SwiftUI
import UIKit
import AVFoundation

protocol PreviewSource: AnyObject, Sendable {
    func connect(to view: PreviewView)
}

struct CameraPreview: UIViewRepresentable {
    let source: PreviewSource
    @Binding var previewView: PreviewView?
    let onTap: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        source.connect(to: view)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        context.coordinator.view = view
        context.coordinator.onTap = onTap
        DispatchQueue.main.async { self.previewView = view }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject {
        weak var view: PreviewView?
        var onTap: ((CGPoint, CGPoint) -> Void)?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = view else { return }
            let viewPoint = recognizer.location(in: view)
            let devicePoint = view.captureDevicePoint(forViewPoint: viewPoint)
            onTap?(devicePoint, viewPoint)
        }
    }
}
