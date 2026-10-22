import SwiftUI

/// A small grey glyph button for the notch header and rows.
struct NotchIconButton: View {
    let symbol: String
    let help: String
    var isActive = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive || isHovered ? NotchStyle.primary : NotchStyle.secondary)
                .frame(width: 26, height: 24)
                .background(isHovered ? NotchStyle.control : .clear, in: .rect(cornerRadius: 7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
