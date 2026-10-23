import CleenKit
import SwiftUI

/// One shortcut: a colored glyph square and its name. A click runs it; the square shows
/// a spinner while it runs, then a check or an error badge. Pin on hover or from the
/// context menu.
struct ShortcutTile: View {
    @Environment(ShortcutsModel.self) private var model
    let entry: ShortcutEntry
    /// The tile Return would run (the top search result).
    var isSuggested = false
    @State private var isHovered = false

    var body: some View {
        let state = model.state(of: entry)
        let pinned = model.isPinned(entry)
        Button { model.run(entry) } label: {
            VStack(spacing: 6) {
                ShortcutTileIcon(name: entry.name, state: state)
                Text(entry.name)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 26, alignment: .top)
            }
            .padding(.top, 10)
            .padding(.bottom, 5)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(isHovered ? NotchStyle.control : NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSuggested ? NotchStyle.primary.opacity(0.35) : NotchStyle.cardStroke)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(ShortcutTileButtonStyle())
        // Outside the button's label so a click on it pins instead of running.
        .overlay(alignment: .topTrailing) {
            if isHovered {
                CardButton(symbol: pinned ? "pin.slash" : "pin", help: pinned ? "Desafixar" : "Fixar") { model.togglePin(entry) }
                    .padding(5)
                    .transition(.opacity)
            } else if pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(NotchStyle.tertiary)
                    .frame(width: 16, height: 16)
                    .padding(5)
                    .accessibilityHidden(true)
            }
        }
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.15)) { isHovered = hovering }
        }
        .contextMenu {
            if state == .running {
                Button("Parar") { model.stop(entry) }
            } else {
                Button("Rodar") { model.run(entry) }
            }
            Button(pinned ? "Desafixar" : "Fixar") { model.togglePin(entry) }
            Divider()
            Button("Abrir no Atalhos") { model.openInShortcuts(entry) }
        }
        .help(help(for: state))
        .accessibilityLabel(entry.name)
        .accessibilityValue(accessibilityValue(for: state, pinned: pinned))
        .accessibilityHint("Roda o atalho")
    }

    private func help(for state: ShortcutsModel.RunState) -> String {
        switch state {
        case .failed(let message): "\(entry.name): \(message)"
        case .running: "\(entry.name) está rodando"
        default: entry.name
        }
    }

    private func accessibilityValue(for state: ShortcutsModel.RunState, pinned: Bool) -> String {
        let status = switch state {
        case .idle: ""
        case .running: "Rodando"
        case .done: "Concluído"
        case .failed(let message): "Falhou: \(message)"
        }
        return [pinned ? "Fixado" : "", status].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// The glyph square, with what the run is doing on top of it.
private struct ShortcutTileIcon: View {
    let name: String
    let state: ShortcutsModel.RunState

    private static let size = 34.0

    var body: some View {
        let glyph = ShortcutGlyph(name: name, paletteCount: ShortcutTileColors.palette.count)
        ToolIcon(symbol: glyph.symbol, color: ShortcutTileColors.palette[glyph.colorIndex], size: Self.size)
            .overlay {
                if state == .running {
                    // The glyph steps back behind a dimmed plate so the spinner reads.
                    RoundedRectangle(cornerRadius: Self.size * 0.26, style: .continuous)
                        .fill(.black.opacity(0.45))
                        .overlay { WingSpinner(size: 16).accessibilityHidden(true) }
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                badge
                    .offset(x: 4, y: 4)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: state)
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .done:
            StatusBadge(symbol: "checkmark", color: NotchStyle.good)
                .transition(.scale(0.4).combined(with: .opacity))
        case .failed:
            StatusBadge(symbol: "exclamationmark", color: NotchStyle.critical)
                .transition(.scale(0.4).combined(with: .opacity))
        case .idle, .running:
            EmptyView()
        }
    }
}

/// A small round mark at the icon's corner, cut out of the tile by a black ring.
private struct StatusBadge: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 15, height: 15)
            .background(color, in: .circle)
            .overlay { Circle().strokeBorder(.black, lineWidth: 1.5).padding(-1.5) }
            .accessibilityHidden(true)
    }
}

/// Press feedback for a tile: a slight sink, quick to come back.
private struct ShortcutTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

/// The colors a tile can get; the shortcut's name picks one. Grays are left out: a gray
/// tile would read as disabled.
enum ShortcutTileColors {
    static let palette: [Color] = [
        ToolPalette.blue, ToolPalette.indigo, ToolPalette.purple, ToolPalette.pink, ToolPalette.red,
        ToolPalette.orange, ToolPalette.yellow, ToolPalette.green, ToolPalette.teal,
    ]
}
