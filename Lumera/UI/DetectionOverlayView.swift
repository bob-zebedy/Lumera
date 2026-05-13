import SwiftUI

struct DetectionOverlayView: View {
    let objects: [DetectedObject]
    let selectedID: Int?
    let previewView: PreviewView?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                ForEach(objects) { object in
                    if let frame = previewView?.viewRect(forMetadataOutputRect: object.bounds) {
                        let isSelected = selectedID == object.id
                        FaceBracket(isSelected: isSelected)
                            .frame(width: frame.width, height: frame.height)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(object.id) }
                            .position(x: frame.midX, y: frame.midY)
                            .animation(.linear(duration: 0.04), value: frame)
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                    }
                }
            }
        }
    }
}

private struct FaceBracket: View {
    let isSelected: Bool

    var body: some View {
        CornerBracketsShape()
            .stroke(strokeColor, lineWidth: lineWidth)
            .shadow(color: glowColor, radius: glowRadius)
            .overlay(alignment: .topTrailing) {
                if isSelected { lockBadge }
            }
    }

    private var strokeColor: Color {
        isSelected ? .yellow : .white.opacity(0.55)
    }

    private var lineWidth: CGFloat {
        isSelected ? 3 : 1.5
    }

    private var glowColor: Color {
        isSelected ? .yellow.opacity(0.7) : .clear
    }

    private var glowRadius: CGFloat {
        isSelected ? 6 : 0
    }

    private var lockBadge: some View {
        Text("AF")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.yellow))
            .shadow(color: .black.opacity(0.4), radius: 1, y: 0.5)
            .offset(x: 4, y: -6)
    }
}

private struct CornerBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let armLength = min(rect.width, rect.height) * 0.22
        let arm = max(8, min(armLength, 22))

        let x0 = rect.minX, y0 = rect.minY
        let x1 = rect.maxX, y1 = rect.maxY

        path.move(to: CGPoint(x: x0, y: y0 + arm))
        path.addLine(to: CGPoint(x: x0, y: y0))
        path.addLine(to: CGPoint(x: x0 + arm, y: y0))

        path.move(to: CGPoint(x: x1 - arm, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y0))
        path.addLine(to: CGPoint(x: x1, y: y0 + arm))

        path.move(to: CGPoint(x: x0, y: y1 - arm))
        path.addLine(to: CGPoint(x: x0, y: y1))
        path.addLine(to: CGPoint(x: x0 + arm, y: y1))

        path.move(to: CGPoint(x: x1 - arm, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x1, y: y1 - arm))

        return path
    }
}
