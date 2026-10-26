import SwiftUI

struct NotchTabButton: View {
    let symbol: String
    /// Draws Claude's mark instead of the symbol (the Agentes tab).
    var showsClaudeLogo = false
    let title: String
    let isSelected: Bool
    /// The dock's shared pill, so it slides from tab to tab.
    let selection: Namespace.ID
    let action: () -> Void
    @State private var isHovered = false

    static let width = 32.0

    var body: some View {
        Button(action: action) {
            Group {
                if showsClaudeLogo {
                    ClaudeLogo(size: 13, tint: foreground)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(foreground)
                }
            }
            .frame(width: Self.width, height: 30)
            .background {
                if isSelected {
                    Capsule()
                        .fill(NotchStyle.control)
                        .matchedGeometryEffect(id: "tab", in: selection)
                } else if isHovered {
                    Capsule().fill(Color.white.opacity(0.05))
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        isSelected ? NotchStyle.primary : (isHovered ? NotchStyle.primary.opacity(0.8) : Color.white.opacity(0.42))
    }
}
