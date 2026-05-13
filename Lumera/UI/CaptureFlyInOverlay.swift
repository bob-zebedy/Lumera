import SwiftUI
import UIKit

struct ThumbnailFramePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

enum CaptureFlyPhase {
    case start, landed, vanish
}

struct CaptureFlyInOverlay: View {
    let image: UIImage
    let targetFrame: CGRect
    let phase: CaptureFlyPhase

    private static let startCornerRadius: CGFloat = 0
    private static let landedCornerRadius: CGFloat = 8
    private static let landedSide: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let target = resolvedTarget(in: proxy.size)
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: phase == .start ? proxy.size.width : Self.landedSide,
                    height: phase == .start ? proxy.size.height : Self.landedSide
                )
                .clipShape(RoundedRectangle(
                    cornerRadius: phase == .start ? Self.startCornerRadius : Self.landedCornerRadius,
                    style: .continuous
                ))
                .shadow(
                    color: .black.opacity(phase == .landed ? 0.4 : 0),
                    radius: phase == .landed ? 10 : 0,
                    y: phase == .landed ? 4 : 0
                )
                .position(
                    x: phase == .start ? centerX : target.midX,
                    y: phase == .start ? centerY : target.midY
                )
                .opacity(phase == .vanish ? 0 : 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func resolvedTarget(in size: CGSize) -> CGRect {
        guard targetFrame.width > 0 else {
            let side: CGFloat = 56
            return CGRect(
                x: 32,
                y: size.height - side - 60,
                width: side,
                height: side
            )
        }
        return targetFrame
    }
}
