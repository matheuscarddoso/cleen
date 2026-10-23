import SwiftUI

/// Opens a row to list what's inside it.
struct DisclosureChevron: View {
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(isExpanded ? String(localized: "Esconder itens") : String(localized: "Ver o que sai"))
        .accessibilityLabel(isExpanded ? String(localized: "Esconder itens") : String(localized: "Ver itens"))
    }
}
