import SwiftUI

struct EVAdjustIndicator: View {
    let bias: Float
    let range: ClosedRange<Float>

    private static let trackWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(bias == 0 ? .yellow : .white)
                .monospacedDigit()
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: Self.trackWidth, height: 3)

                Rectangle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 2, height: 10)
                    .offset(x: zeroMarkerX)

                Circle()
                    .fill(bias == 0 ? Color.yellow : Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: biasMarkerX)
            }
            .frame(width: Self.trackWidth, height: 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.65)))
    }

    private var label: String {
        if bias == 0 { return "0.0" }
        return String(format: "%+.1f", bias)
    }

    private var zeroMarkerX: CGFloat { offsetX(for: 0) }
    private var biasMarkerX: CGFloat { offsetX(for: bias) }

    private func offsetX(for value: Float) -> CGFloat {
        let lower = CGFloat(range.lowerBound)
        let upper = CGFloat(range.upperBound)
        let span = upper - lower
        guard span > 0 else { return 0 }
        let ratio = (CGFloat(value) - lower) / span
        return ratio * Self.trackWidth - Self.trackWidth / 2
    }
}

struct LaunchSplash: View {
    @State private var iconScale: CGFloat = 0.72
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 8

    private static let logoSize: CGFloat = 96
    private static let cornerRadius: CGFloat = logoSize * 0.2237

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Self.logoSize, height: Self.logoSize)
                    .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                Text("Lumera")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .tracking(1.2)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
            }
        }
        .task {
            withAnimation(.spring(duration: 0.65, bounce: 0.32)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.45)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }
    }
}

struct DiffuseModifier: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var diffuse: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .modifier(
                active: DiffuseModifier(scale: 1.55, blur: 22, opacity: 0),
                identity: DiffuseModifier(scale: 1.0, blur: 0, opacity: 1)
            )
        )
    }
}
