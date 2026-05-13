import SwiftUI

extension View {

    func glassButtonLabelShadow() -> some View {
        shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 0.5)
    }

    @ViewBuilder
    func liquidGlassCircle(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: Circle())
            } else {
                self.glassEffect(.regular, in: Circle())
            }
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }

    @ViewBuilder
    func liquidGlassCapsule(interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: Capsule())
            } else {
                self.glassEffect(.regular, in: Capsule())
            }
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func liquidGlassRect(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    func conditionalGlassCapsule(highlighted: Bool, highlightColor: Color) -> some View {
        if highlighted {
            self.background(Capsule().fill(highlightColor))
        } else {
            self.liquidGlassCapsule(interactive: true)
        }
    }
}

struct GlassyContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
