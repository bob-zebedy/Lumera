import SwiftUI

struct HDRButton: View {
    let isOn: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isOn ? "h.square.fill" : "h.square")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isOn ? .yellow : .white)
                .glassButtonLabelShadow()
                .frame(width: 36, height: 36)
                .liquidGlassCircle(interactive: true)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("HDR"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}
