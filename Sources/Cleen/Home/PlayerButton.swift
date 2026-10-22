import SwiftUI

struct PlayerButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NotchStyle.primary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 34, height: 34)
                .background(isHovered ? Color.white.opacity(0.14) : .clear, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .accessibilityLabel(label)
    }
}
