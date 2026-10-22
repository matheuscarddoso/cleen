import SwiftUI

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.secondary))
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface), in: .capsule)
                .overlay { Capsule().strokeBorder(isSelected ? .clear : Theme.hairline) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(Theme.quick, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
