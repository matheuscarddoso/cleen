import SwiftUI

/// The one loud button on a screen: champagne capsule.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14 : 13, weight: .medium))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, large ? 22 : 16)
            .frame(height: large ? 40 : 32)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.35), in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.quick, value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryLarge: PrimaryButtonStyle { PrimaryButtonStyle(large: true) }
}
