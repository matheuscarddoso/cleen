import SwiftUI

/// The tour's buttons: a light, solid primary with the Return glyph (it answers to the
/// key), and a quiet text secondary.
struct OnboardingButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind = Kind.primary
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            if kind == .primary {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.45)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(kind == .primary ? Color.black : (isHovered ? NotchStyle.primary : NotchStyle.secondary))
        .padding(.horizontal, kind == .primary ? 20 : 12)
        .frame(height: 40)
        .background(background(pressed: configuration.isPressed), in: .rect(cornerRadius: 12, style: .continuous))
        .opacity(isEnabled ? 1 : 0.4)
        .scaleEffect(configuration.isPressed ? 0.96 : 1)
        .contentShape(.rect(cornerRadius: 12, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: configuration.isPressed)
        .animation(.smooth(duration: 0.15), value: isHovered)
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: Color(white: pressed ? 0.78 : (isHovered ? 0.95 : 0.88))
        case .secondary: pressed ? NotchStyle.control : .clear
        }
    }
}

extension ButtonStyle where Self == OnboardingButtonStyle {
    static var onboardingPrimary: OnboardingButtonStyle { OnboardingButtonStyle(kind: .primary) }
    static var onboardingSecondary: OnboardingButtonStyle { OnboardingButtonStyle(kind: .secondary) }
}
