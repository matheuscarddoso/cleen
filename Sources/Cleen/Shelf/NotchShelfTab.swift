import SwiftUI

/// The shelf: a header row (what's there, empty, AirDrop) over the tray. While
/// files are dragged to the notch, the tab turns into two drop zones: keep on the
/// shelf, or send by AirDrop.
struct NotchShelfTab: View {
    @Environment(ShelfModel.self) private var shelf
    @Environment(NotchState.self) private var notch

    var body: some View {
        ZStack {
            if showsDropZones {
                ShelfDropZones()
                    .transition(.opacity.combined(with: .scale(0.97)))
            } else {
                VStack(spacing: 8) {
                    ShelfHeader()
                    ShelfTray()
                }
                .transition(.opacity)
            }
        }
        .padding(.bottom, 4)
        .animation(.smooth(duration: 0.2), value: showsDropZones)
        .onAppear {
            shelf.prune()
            // Esc lets go of the selection first; the next one closes the notch.
            notch.escapeHandler = { [shelf] in
                guard !shelf.selection.isEmpty else { return false }
                shelf.selection.clear()
                return true
            }
        }
        .onDisappear {
            notch.escapeHandler = nil
            notch.isDraggingFiles = false
        }
    }

    /// Only for files coming in: the tray's own files on their way out don't count.
    private var showsDropZones: Bool {
        notch.isDraggingFiles && !shelf.isDraggingOut
    }
}

/// What's on the shelf on the left; empty and AirDrop on the right.
private struct ShelfHeader: View {
    @Environment(ShelfModel.self) private var shelf

    var body: some View {
        HStack(spacing: 4) {
            Text(summary)
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
                .contentTransition(.opacity)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !shelf.items.isEmpty {
                NotchIconButton(symbol: "xmark", help: removeHelp) {
                    withAnimation(.smooth(duration: 0.25)) {
                        if shelf.selection.isEmpty { shelf.clear() } else { shelf.removeSelected() }
                    }
                }
                .padding(.trailing, 4)
            }
            AirDropButton()
        }
        .frame(height: 24)
        .animation(.smooth(duration: 0.2), value: shelf.selection.count)
    }

    private var summary: String {
        let total = shelf.items.count
        let picked = shelf.selection.count
        if total == 0 { return String(localized: "Os arquivos ficam aqui por um dia, sem sair do lugar") }
        if picked > 0 {
            return picked.counted(String(localized: "\(picked) de \(total) selecionado"), String(localized: "\(picked) de \(total) selecionados"))
        }
        let files = total.counted(String(localized: "\(total) arquivo"), String(localized: "\(total) arquivos"))
        return String(localized: "\(files) · ficam por um dia")
    }

    private var removeHelp: String {
        shelf.selection.isEmpty ? String(localized: "Esvaziar a Shelf") : String(localized: "Tirar os selecionados da Shelf")
    }
}
