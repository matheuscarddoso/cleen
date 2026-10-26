import SwiftUI

/// Every tool, behind the dock's grid button: the everyday ones first, then the Mac's
/// upkeep grouped under Limpeza. A click opens one; the context menu pins it to the dock.
struct NotchAllTools: View {
    @Environment(NotchState.self) private var state
    @Environment(TabPreferences.self) private var tabs

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    var body: some View {
        NotchScroll {
            VStack(alignment: .leading, spacing: 16) {
                section(String(localized: "Ferramentas"), tabs.visible.filter { !$0.isCleaning })
                section(String(localized: "Limpeza do Mac"), tabs.visible.filter(\.isCleaning))
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [NotchTab]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotchStyle.tertiary)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(items) { tab in
                        ToolTile(tab: tab, isCurrent: tab == state.tab, isPinned: tabs.isPinned(tab)) {
                            withAnimation(NotchController.searchResize) { state.tab = tab }
                        }
                        .contextMenu {
                            if tabs.isPinned(tab) {
                                if tab != .home {
                                    Button("Tirar da dock") { tabs.setPinned(false, for: tab) }
                                }
                            } else {
                                Button("Fixar na dock") { tabs.setPinned(true, for: tab) }
                                    .disabled(tabs.pinned.count >= TabPreferences.maxPinned)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One tool: its icon on a rounded square, its name under it.
private struct ToolTile: View {
    let tab: NotchTab
    let isCurrent: Bool
    let isPinned: Bool
    let open: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            VStack(spacing: 6) {
                Group {
                    if tab == .agents {
                        ClaudeLogo(size: 17, tint: NotchStyle.primary)
                    } else {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(width: 40, height: 40)
                .background(isCurrent ? NotchStyle.controlHover : (isHovered ? NotchStyle.control : NotchStyle.card), in: .rect(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
                .overlay(alignment: .topTrailing) {
                    if isPinned {
                        Circle().fill(NotchStyle.secondary).frame(width: 4, height: 4).offset(x: -5, y: 5)
                    }
                }
                .scaleEffect(isHovered ? 1.04 : 1)
                Text(tab.settingsTitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(isCurrent ? NotchStyle.primary : NotchStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .help(tab.title)
    }
}
