import SwiftUI

struct AspectRatioMaskView: View {
    let ratio: AspectRatio

    private static let maskOpacity: Double = 0.55

    var body: some View {
        GeometryReader { proxy in
            let visible = visibleRect(in: proxy.size)
            maskOverlay(in: proxy.size, visible: visible)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.28), value: ratio)
    }

    private func maskOverlay(in size: CGSize, visible: CGRect) -> some View {
        ZStack {
            Color.black.opacity(Self.maskOpacity)
                .frame(width: size.width, height: max(0, visible.minY))
                .position(x: size.width / 2, y: visible.minY / 2)

            Color.black.opacity(Self.maskOpacity)
                .frame(
                    width: size.width,
                    height: max(0, size.height - visible.maxY)
                )
                .position(
                    x: size.width / 2,
                    y: (visible.maxY + size.height) / 2
                )

            Color.black.opacity(Self.maskOpacity)
                .frame(width: max(0, visible.minX), height: visible.height)
                .position(x: visible.minX / 2, y: visible.midY)

            Color.black.opacity(Self.maskOpacity)
                .frame(
                    width: max(0, size.width - visible.maxX),
                    height: visible.height
                )
                .position(
                    x: (visible.maxX + size.width) / 2,
                    y: visible.midY
                )
        }
    }

    private func visibleRect(in size: CGSize) -> CGRect {
        guard ratio.showsMask else {
            return CGRect(origin: .zero, size: size)
        }
        let target = ratio.widthOverHeight
        let containerAspect = size.width / size.height
        let portrait = containerAspect < 1
        let effectiveTarget = portrait ? 1 / target : target

        let visibleW: CGFloat
        let visibleH: CGFloat
        if containerAspect > effectiveTarget {
            visibleH = size.height
            visibleW = visibleH * effectiveTarget
        } else {
            visibleW = size.width
            visibleH = visibleW / effectiveTarget
        }
        return CGRect(
            x: (size.width - visibleW) / 2,
            y: (size.height - visibleH) / 2,
            width: visibleW,
            height: visibleH
        )
    }
}
