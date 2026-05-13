import SwiftUI

struct LensSelectorView: View {
    let lenses: [Lens]
    let selected: Lens
    let zoomFactors: [Lens: Double]
    var axis: Axis = .horizontal
    let onSelect: (Lens) -> Void

    var body: some View {
        let layout: AnyLayout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 6))
            : AnyLayout(VStackLayout(spacing: 6))

        layout {
            ForEach(lenses) { lens in
                lensButton(lens)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .liquidGlassCapsule()
    }

    private func lensButton(_ lens: Lens) -> some View {
        let isSelected = selected == lens
        return Button {
            onSelect(lens)
        } label: {
            Text(lens.dynamicLabel(zoomFactor: zoomFactors[lens]))
                .font(.system(
                    size: isSelected ? 15 : 13,
                    weight: isSelected ? .bold : .medium,
                    design: .rounded
                ))
                .foregroundStyle(isSelected ? Color.yellow : .white)
                .glassButtonLabelShadow()
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.yellow.opacity(isSelected ? 0.18 : 0))
                )
                .contentShape(Circle())
                .animation(.spring(duration: 0.32, bounce: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
