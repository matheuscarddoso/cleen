import CleenKit
import SwiftUI

/// Clipboard history as in OmniNotch: search and type pills on top, the copies as a
/// row of cards. Click a card to paste it; ← → move, Return pastes.
struct NotchClipboardTab: View {
    @Environment(ClipboardModel.self) private var model
    @Environment(NotchState.self) private var notch
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                    TextField("Buscar", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($searchFocused)
                        .onSubmit(pasteSelected)
                }
                .padding(.horizontal, 9)
                .frame(width: 200, height: 26)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.18))
                }
                ClipboardKindPill(title: "Tudo", isSelected: model.kind == nil) { model.kind = nil }
                ForEach(ClipboardEntry.Kind.allCases, id: \.self) { kind in
                    ClipboardKindPill(title: kind.title, isSelected: model.kind == kind) { model.kind = kind }
                }
                Spacer()
                ClipboardMoreMenu()
            }
            ClipboardCards(paste: paste)
        }
        .onKeyPress(.leftArrow) { model.moveSelection(by: -1); return .handled }
        .onKeyPress(.rightArrow) { model.moveSelection(by: 1); return .handled }
        .onAppear { searchFocused = true }
    }

    private func pasteSelected() {
        if let entry = model.selected { paste(entry) }
    }

    private func paste(_ entry: ClipboardEntry) {
        notch.isPinned = false
        model.paste(entry)
    }
}
