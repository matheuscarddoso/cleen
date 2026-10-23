import SwiftUI

/// One tool in the tabs page's grid: lit when it's in the notch's bar.
struct TabChip: View {
    let tab: NotchTab
    let isOn: Bool
    let toggle: () -> Void
    @State private var isHovered = false

    /// Short enough for a third of the column.
    private var name: String {
        switch tab {
        case .clipboard: String(localized: "Transferência")
        case .files: String(localized: "Arquivos")
        case .apps: String(localized: "Desinstalar")
        case .leftovers: String(localized: "Restos")
        case .space: String(localized: "Mapa do disco")
        default: tab.settingsTitle
        }
    }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 7) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 10.5, weight: .medium))
                    .frame(width: 14)
                Text(name)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? NotchStyle.primary : NotchStyle.tertiary)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(isOn ? NotchStyle.selection : (isHovered ? NotchStyle.card : .clear), in: .rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isOn ? Color.white.opacity(0.14) : NotchStyle.cardStroke)
            }
            .contentShape(.rect(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
