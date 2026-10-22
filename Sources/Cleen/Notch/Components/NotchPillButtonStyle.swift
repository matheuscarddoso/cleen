import SwiftUI

/// Notch buttons. `.primary` is the white pill with black text; `.secondary` is a grey
/// pill; `.destructive` is the red one used while confirming.
struct NotchPillButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    var kind = Kind.primary
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotchStyle.bodyMedium)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(background(pressed: configuration.isPressed), in: .capsule)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(.capsule)
            .onHover { isHovered = $0 }
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
            .animation(.smooth(duration: 0.15), value: isHovered)
    }

    private var foreground: Color {
        kind == .primary ? .black : .white
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: Color.white.opacity(pressed ? 0.8 : (isHovered ? 0.92 : 1))
        case .secondary: pressed || isHovered ? NotchStyle.controlHover : NotchStyle.control
        case .destructive: NotchStyle.critical.opacity(pressed ? 0.8 : 1)
        }
    }
}

extension ButtonStyle where Self == NotchPillButtonStyle {
    static var notchPrimary: NotchPillButtonStyle { NotchPillButtonStyle(kind: .primary) }
    static var notchSecondary: NotchPillButtonStyle { NotchPillButtonStyle(kind: .secondary) }
    static var notchDestructive: NotchPillButtonStyle { NotchPillButtonStyle(kind: .destructive) }
}
