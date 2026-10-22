import SwiftUI

/// "Sistema ›": a section title that jumps to the tool it summarizes.
struct NotchSectionLink: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(NotchStyle.tertiary)
                    .offset(x: isHovered ? 1.5 : 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .accessibilityAddTraits(.isHeader)
    }
}
