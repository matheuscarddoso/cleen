import SwiftUI

struct NotchTabButton: View {
    let symbol: String
    /// Draws Claude's mark instead of the symbol (the Agentes tab).
    var showsClaudeLogo = false
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if showsClaudeLogo {
                    ClaudeLogo(size: 14, tint: foreground)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(foreground)
                }
            }
                .frame(width: 30, height: 26)
                .background(isSelected ? NotchStyle.selection : (isHovered ? NotchStyle.control : .clear), in: .rect(cornerRadius: 7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        isSelected ? NotchStyle.primary : (isHovered ? NotchStyle.primary.opacity(0.8) : NotchStyle.secondary)
    }
}
