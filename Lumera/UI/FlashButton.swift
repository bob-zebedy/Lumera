import SwiftUI

struct FlashButton: View {
    let mode: FlashMode
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: mode.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tintColor)
                .glassButtonLabelShadow()
                .frame(width: 36, height: 36)
                .liquidGlassCircle(interactive: true)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.4)
        .accessibilityLabel(Text("Flash"))
        .accessibilityValue(Text(accessibilityValue))
    }

    private var tintColor: Color {
        switch mode {
        case .off:  return .white
        case .auto: return .yellow
        case .on:   return .yellow
        }
    }

    private var accessibilityValue: String {
        switch mode {
        case .off:  return String(localized: "Off")
        case .auto: return String(localized: "Auto")
        case .on:   return String(localized: "On")
        }
    }
}
