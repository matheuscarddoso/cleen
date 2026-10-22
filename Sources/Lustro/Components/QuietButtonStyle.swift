import SwiftUI

/// Secondary actions: hairline capsule that fills on hover.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 13)
            .frame(height: 28)
            .background(isHovered || configuration.isPressed ? Theme.surfaceHover : .clear, in: .capsule)
            .overlay { Capsule().strokeBorder(Theme.hairline) }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(.capsule)
            .onHover { isHovered = $0 }
            .animation(Theme.quick, value: isHovered)
    }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}
