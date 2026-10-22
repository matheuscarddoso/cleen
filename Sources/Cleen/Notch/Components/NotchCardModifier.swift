import SwiftUI

/// The dark gradient tile the notch groups content in.
struct NotchCardModifier: ViewModifier {
    var padding = 12.0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(NotchStyle.card, in: .rect(cornerRadius: NotchStyle.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NotchStyle.cardRadius, style: .continuous)
                    .strokeBorder(NotchStyle.cardStroke, lineWidth: 1)
            }
    }
}

extension View {
    func notchCard(padding: Double = 12) -> some View {
        modifier(NotchCardModifier(padding: padding))
    }
}
