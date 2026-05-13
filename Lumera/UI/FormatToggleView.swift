import SwiftUI

struct FormatToggleView: View {
    let selected: PhotoFormat
    let onSelect: (PhotoFormat) -> Void

    var body: some View {
        Button {
            onSelect(selected.next)
        } label: {
            Text(selected.shortLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.yellow)
                .glassButtonLabelShadow()
                .frame(minWidth: 30, minHeight: 14)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlassCapsule(interactive: true)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Format")
        .accessibilityValue(selected.fullLabel)
    }
}

private extension PhotoFormat {
    var next: PhotoFormat {
        let all = PhotoFormat.allCases
        guard let i = all.firstIndex(of: self) else { return all.first ?? self }
        return all[(i + 1) % all.count]
    }
}
