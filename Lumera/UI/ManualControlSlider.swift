import SwiftUI

struct ManualControlSlider: View {
    let title: LocalizedStringKey
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var reversed: Bool = false
    var tickCount: Int? = nil
    var minLabel: Text? = nil
    var maxLabel: Text? = nil
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(valueText)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.yellow)
            }
            sliderControl
                .tint(.yellow)
            if minLabel != nil || maxLabel != nil {
                HStack {
                    if let minLabel {
                        minLabel
                    }
                    Spacer()
                    if let maxLabel {
                        maxLabel
                    }
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlassRect(cornerRadius: 12)
    }

    private var sliderControl: some View {
        let lower = range.lowerBound
        let upper = range.upperBound
        let span = upper - lower

        return GeometryReader { geo in
            let thumbWidth: CGFloat = 6
            let thumbHeight: CGFloat = 22
            let inset = thumbWidth / 2
            let trackWidth = max(0, geo.size.width - thumbWidth)
            let raw = span > 0 ? (sliderBinding.wrappedValue - lower) / span : 0
            let normalized = max(0, min(1, raw))
            let thumbX = inset + trackWidth * CGFloat(normalized)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)
                    .padding(.horizontal, inset)

                if let tickCount, tickCount > 1 {
                    let denom = max(tickCount - 1, 1)
                    ForEach(0..<tickCount, id: \.self) { i in
                        let isEdge = (i == 0 || i == tickCount - 1)
                        Rectangle()
                            .fill(Color.white.opacity(isEdge ? 0.55 : 0.25))
                            .frame(width: 1.2, height: isEdge ? 8 : 5)
                            .offset(x: inset + trackWidth * CGFloat(i) / CGFloat(denom) - 0.6)
                    }
                }

                Capsule()
                    .fill(Color.yellow)
                    .frame(width: max(0, thumbX - inset), height: 3)
                    .offset(x: inset)

                RoundedRectangle(cornerRadius: thumbWidth / 2, style: .continuous)
                    .fill(Color.white)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: thumbX - inset)
            }
            .frame(height: thumbHeight, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard trackWidth > 0 else { return }
                        let x = value.location.x - inset
                        let frac = max(0, min(1, x / trackWidth))
                        let newValue: Double
                        if let tickCount, tickCount > 1 {
                            let denom = max(tickCount - 1, 1)
                            let snappedIdx = (frac * CGFloat(denom)).rounded()
                            newValue = lower + Double(snappedIdx) * span / Double(denom)
                        } else {
                            newValue = lower + Double(frac) * span
                        }
                        if newValue != sliderBinding.wrappedValue {
                            sliderBinding.wrappedValue = newValue

                            onCommit()
                        }
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .frame(height: 22)
    }

    private var sliderBinding: Binding<Double> {
        guard reversed else { return $value }
        let r = range
        return Binding(
            get: { r.upperBound + r.lowerBound - value },
            set: { value = r.upperBound + r.lowerBound - $0 }
        )
    }
}
