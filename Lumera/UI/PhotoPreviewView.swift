import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    var coachStep: CoachStep?
    var coachStepIndex: Int = 0
    var coachTotalSteps: Int = 0
    var onCoachSkip: () -> Void = {}
    var onCoachNext: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var dragOpacity: Double = 1.0
    @State private var isZoomed = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(dragOpacity)
                .ignoresSafeArea()

            ZoomableImageView(image: image, isZoomed: $isZoomed)
                .ignoresSafeArea()
                .offset(y: dragOffset)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .gesture(swipeDownDismiss, including: isZoomed ? .subviews : .all)
        .overlay {
            if let step = coachStep {
                GeometryReader { proxy in
                    CoachMarkOverlay(
                        step: step,
                        stepIndex: coachStepIndex,
                        totalSteps: coachTotalSteps,
                        anchors: [:],
                        geometry: proxy,
                        onSkip: onCoachSkip,
                        onNext: onCoachNext
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
    }

    private var swipeDownDismiss: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard value.translation.height > 0,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation.height
                dragOpacity = max(0.4, 1.0 - Double(value.translation.height) / 400.0)
            }
            .onEnded { value in
                if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                        dragOpacity = 1.0
                    }
                }
            }
    }
}
