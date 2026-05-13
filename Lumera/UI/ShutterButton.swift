import SwiftUI

struct ShutterButton: View {
    let isCapturing: Bool
    let burstCount: Int
    let onTap: () -> Void
    let onBurstStart: () -> Void
    let onBurstEnd: () -> Void

    @State private var isPressing = false
    @State private var didStartBurst = false
    @State private var burstPulse = false

    private static let longPressThresholdMs: Int = 300

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 78, height: 78)

            if didStartBurst {
                burstDots
            } else {
                Circle()
                    .fill(.white)
                    .frame(width: isCapturing ? 50 : 64, height: isCapturing ? 50 : 64)
                    .opacity(isCapturing ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isCapturing)
            }

            if didStartBurst, burstCount > 0 {
                Text("\(burstCount)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: 30, y: -30)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .contentShape(Circle())
        .accessibilityLabel("Shutter")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressing else { return }
                    isPressing = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(Self.longPressThresholdMs))
                        if isPressing, !didStartBurst {
                            withAnimation(.easeOut(duration: 0.18)) {
                                didStartBurst = true
                            }
                            onBurstStart()
                        }
                    }
                }
                .onEnded { _ in
                    let wasBurst = didStartBurst
                    isPressing = false
                    withAnimation(.easeOut(duration: 0.18)) {
                        didStartBurst = false
                    }
                    if wasBurst {
                        onBurstEnd()
                    } else {
                        onTap()
                    }
                }
        )
    }

    private var burstDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .opacity(burstPulse ? 0.35 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: burstPulse
                    )
            }
        }
        .onAppear { burstPulse = true }
        .onDisappear { burstPulse = false }
    }
}
