import SwiftUI

struct FocusReticle: View {
    let position: CGPoint

    @State private var animating = false

    var body: some View {
        Rectangle()
            .stroke(Color.yellow, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .scaleEffect(animating ? 1.0 : 1.4)
            .opacity(animating ? 1.0 : 0.0)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) { animating = true }
            }
            .allowsHitTesting(false)
    }
}
