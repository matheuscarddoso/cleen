import SwiftUI

struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: section.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                Text(section.title)
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? NotchStyle.primary : NotchStyle.primary.opacity(0.7))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(isSelected ? NotchStyle.selection : (isHovered ? NotchStyle.control.opacity(0.5) : .clear), in: .rect(cornerRadius: 7, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
