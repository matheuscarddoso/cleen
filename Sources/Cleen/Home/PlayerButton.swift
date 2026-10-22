import SwiftUI

struct PlayerButton: View {
    let symbol: String
    let label: String
    let size: Double
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 28)
                .contentShape(.rect)
                .opacity(isHovered ? 1 : 0.9)
                .scaleEffect(isHovered ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .accessibilityLabel(label)
    }
}
