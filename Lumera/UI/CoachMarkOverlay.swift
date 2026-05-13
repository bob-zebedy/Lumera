import SwiftUI

enum CoachMark: String, CaseIterable, Hashable {
    case lens
    case format
    case hdr
    case flash
    case panelOpen
    case panelClose
    case ev
    case shutter
    case thumbnail
    case previewClose
    case settings
}

enum CoachShape {
    case capsule
    case circle
    case roundedRect(CGFloat)
}

enum CoachDirection: Hashable {
    case up, down, left, right

    var systemImage: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var translation: CGSize {
        switch self {
        case .up:    return CGSize(width: 0, height: -18)
        case .down:  return CGSize(width: 0, height: 18)
        case .left:  return CGSize(width: -18, height: 0)
        case .right: return CGSize(width: 18, height: 0)
        }
    }
}

struct CoachStep: Identifiable {
    var id: CoachMark { mark }
    let mark: CoachMark
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let shape: CoachShape
    let padding: CGFloat
    var directions: [CoachDirection] = []
}

let coachSteps: [CoachStep] = [
    .init(mark: .lens,
          title: "Choose a Lens",
          description: "Tap a lens chip to switch lens",
          shape: .capsule, padding: 6),
    .init(mark: .format,
          title: "Photo Format",
          description: "HEIF / RAW / RAW+HEIF",
          shape: .capsule, padding: 6),
    .init(mark: .hdr,
          title: "HDR Mode",
          description: "Enable HDR",
          shape: .circle, padding: 4),
    .init(mark: .flash,
          title: "Flash Mode",
          description: "Off / Auto / Force On",
          shape: .circle, padding: 4),
    .init(mark: .panelOpen,
          title: "Manual Mode",
          description: "Swipe up anywhere on screen",
          shape: .roundedRect(14), padding: 8,
          directions: [.up]),
    .init(mark: .panelClose,
          title: "Auto Mode",
          description: "Swipe down anywhere on screen",
          shape: .roundedRect(14), padding: 8,
          directions: [.down]),
    .init(mark: .ev,
          title: "Exposure Compensation",
          description: "Swipe left or right anywhere in auto mode",
          shape: .roundedRect(14), padding: 8,
          directions: [.left, .right]),
    .init(mark: .shutter,
          title: "Take a Photo",
          description: "Tap the shutter or use volume keys",
          shape: .circle, padding: 6),
    .init(mark: .thumbnail,
          title: "View Photo",
          description: "Preview the last captured photo",
          shape: .roundedRect(8), padding: 6),
    .init(mark: .previewClose,
          title: "Back to Camera",
          description: "Swipe down on the photo",
          shape: .roundedRect(14), padding: 8,
          directions: [.down]),
    .init(mark: .settings,
          title: "Open Settings",
          description: "Tap the gear icon",
          shape: .circle, padding: 6)
]

struct CoachMarkAnchorPreference: PreferenceKey {
    static var defaultValue: [CoachMark: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachMark: Anchor<CGRect>],
                       nextValue: () -> [CoachMark: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func coachMark(_ mark: CoachMark) -> some View {
        anchorPreference(key: CoachMarkAnchorPreference.self, value: .bounds) { anchor in
            [mark: anchor]
        }
    }
}

struct CoachMarkOverlay: View {
    let step: CoachStep
    let stepIndex: Int
    let totalSteps: Int
    let anchors: [CoachMark: Anchor<CGRect>]
    let geometry: GeometryProxy
    let onSkip: () -> Void
    let onNext: () -> Void

    @State private var pulse = false

    var body: some View {
        let rect = anchors[step.mark].map { geometry[$0] }
        let cutoutFrame = (rect ?? .zero).insetBy(dx: -step.padding, dy: -step.padding)

        ZStack {

            Color.black.opacity(0.7)
                .mask {
                    Rectangle()
                        .fill(.white)
                        .overlay {
                            if rect != nil {
                                cutoutShape(step.shape)
                                    .frame(width: cutoutFrame.width, height: cutoutFrame.height)
                                    .position(x: cutoutFrame.midX, y: cutoutFrame.midY)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if rect != nil {
                cutoutShape(step.shape)
                    .stroke(Color.yellow.opacity(pulse ? 0.95 : 0.5), lineWidth: 2)
                    .frame(width: cutoutFrame.width, height: cutoutFrame.height)
                    .position(x: cutoutFrame.midX, y: cutoutFrame.midY)
                    .allowsHitTesting(false)
            }

            if !step.directions.isEmpty {
                directionArrows
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            bubblePosition(holeMidY: rect?.midY ?? geometry.size.height / 2) {
                bubble
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private var directionArrows: some View {
        HStack(spacing: 56) {
            ForEach(step.directions, id: \.self) { dir in
                CoachDirectionArrow(direction: dir)
            }
        }
    }

    private func cutoutShape(_ shape: CoachShape) -> AnyShape {
        switch shape {
        case .capsule:               return AnyShape(Capsule())
        case .circle:                return AnyShape(Circle())
        case .roundedRect(let r):    return AnyShape(RoundedRectangle(cornerRadius: r))
        }
    }

    @ViewBuilder
    private func bubblePosition<C: View>(holeMidY: CGFloat, @ViewBuilder content: () -> C) -> some View {
        let bubbleAtTop = holeMidY > geometry.size.height / 2
        VStack {
            if bubbleAtTop {
                content()
                    .padding(.top, 60)
                Spacer()
            } else {
                Spacer()
                content()
                    .padding(.bottom, 60)
            }
        }
        .padding(.horizontal, 20)
    }

    private var bubble: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(step.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == stepIndex ? Color.yellow : Color.white.opacity(0.35))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .liquidGlassCapsule(interactive: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onNext()
                } label: {
                    Text(stepIndex == totalSteps - 1 ? "Done" : "Next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.yellow))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: 360)
        .liquidGlassRect(cornerRadius: 18)
        .contentShape(Rectangle())
        .onTapGesture { }
    }
}

private struct CoachDirectionArrow: View {
    let direction: CoachDirection
    @State private var animating = false

    var body: some View {
        Image(systemName: direction.systemImage)
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.yellow)
            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)
            .offset(animating ? direction.translation : .zero)
            .opacity(animating ? 0.45 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    animating = true
                }
            }
    }
}
