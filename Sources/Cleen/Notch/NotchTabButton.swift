import SwiftUI

struct NotchTabButton: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? NotchStyle.primary : (isHovered ? NotchStyle.primary.opacity(0.8) : NotchStyle.secondary))
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
}
