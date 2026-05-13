import SwiftUI

struct AspectRatioButton: View {
    let ratio: AspectRatio
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(ratio.label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .glassButtonLabelShadow()
                .contentTransition(.identity)
                .animation(nil, value: ratio)
                .frame(width: 36, height: 36)
                .liquidGlassCircle(interactive: true)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .accessibilityLabel(Text("Aspect Ratio"))
        .accessibilityValue(Text(ratio.label))
    }
}
