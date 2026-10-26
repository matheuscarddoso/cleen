import AppKit
import SwiftUI

/// The launcher inside the notch: a field, then results grouped by kind. Arrows move,
/// Return runs, ⌘K shows what else the row can do, ⌘Return runs the first of those,
/// Esc steps back — it never needs the mouse.
struct NotchSearchView: View {
    let controller: NotchController
    @Environment(SearchModel.self) private var search
    @Environment(NotchState.self) private var state
    @FocusState private var focused: Bool
    /// Where the pointer was when the list last changed. Rows sliding under a pointer
    /// that hasn't moved mustn't take the selection, as in Raycast; only moving it does.
    @State private var restingPointer: CGPoint?

    var body: some View {
        @Bindable var search = search
        VStack(spacing: 0) {
            // Raycast's layout: the field bare on top, a hairline, the list, and a bar of
            // keys at the bottom. Nothing boxed, so the rows get the room.
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                if search.mode != .all {
                    Button { search.setMode(.all) } label: {
                        Text(search.mode.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NotchStyle.primary)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(NotchStyle.control, in: .rect(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Voltar para tudo")
                }
                TextField(search.mode.placeholder, text: $search.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit(runSelected)
                    .onKeyPress(.downArrow) { search.move(1); return .handled }
                    .onKeyPress(.upArrow) { search.move(-1); return .handled }
                    .onKeyPress(.tab) { search.move(1); return .handled }
                    .onKeyPress(keys: ["k"]) { press in
                        guard press.modifiers.contains(.command), search.selectedItem != nil else { return .ignored }
                        search.showsActions.toggle()
                        return .handled
                    }
                    .onKeyPress(phases: .down) { press in
                        runShortcut(press) ? .handled : .ignored
                    }
                    .onKeyPress(.delete) {
                        // ⌫ on an empty field leaves the narrowed mode.
                        guard search.query.isEmpty, search.mode != .all else { return .ignored }
                        search.setMode(.all)
                        return .handled
                    }
                if !search.query.isEmpty {
                    Button {
                        search.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(NotchStyle.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Limpar a busca")
                }
            }
            .padding(.horizontal, NotchOpenContent.inset)
            .frame(height: 40)

            Rectangle()
                .fill(NotchStyle.separator)
                .frame(height: 1)

            results
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if search.showsActions, let item = search.selectedItem {
                        SearchActionPanel(item: item, actions: search.actions(for: item)) { perform($0, of: item) }
                            .padding(.trailing, 12)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottomTrailing)))
                    }
                }
                .animation(.smooth(duration: 0.18), value: search.showsActions)

            footer
        }
        .onChange(of: search.query, initial: true) { restingPointer = NSEvent.mouseLocation }
        .onAppear {
            focused = true
            state.escapeHandler = { [search] in
                // Esc steps back one level before it closes the launcher.
                if search.editing != nil {
                    search.cancelEditing()
                } else if search.showsActions {
                    search.showsActions = false
                } else if search.mode != .all {
                    search.setMode(.all)
                } else {
                    return false
                }
                return true
            }
        }
        .onDisappear { state.escapeHandler = nil }
        .onChange(of: state.searchFocusRequest) { focused = true }
        .onChange(of: search.editing) { _, editing in
            // Back from the alias field: the keyboard returns to the search.
            if editing == nil { focused = true }
        }
    }

    @ViewBuilder
    private var results: some View {
        if search.sections.isEmpty {
            Text(emptyText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let selectedID = search.selectedItem?.id
                        ForEach(search.sections) { section in
                            Text(section.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NotchStyle.tertiary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 3)
                            ForEach(section.items) { item in
                                SearchRow(item: item, isSelected: item.id == selectedID, alias: search.library.aliases[item.id], hotKey: search.library.hotKeys[item.id])
                                    .id(item.id)
                                    .onTapGesture { perform(item) }
                                    .onHover { hovering in
                                        let pointer = NSEvent.mouseLocation
                                        guard hovering, pointer != restingPointer, !search.showsActions else { return }
                                        restingPointer = nil
                                        if let index = search.items.firstIndex(where: { $0.id == item.id }) { search.selection = index }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.never)
                .scrollEdgeFade()
                .onChange(of: search.selection) {
                    if let id = search.selectedItem?.id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private var emptyText: String {
        switch search.mode {
        case .files: search.query.count < 2 ? String(localized: "Digite parte do nome do arquivo") : (search.files.isSearching ? String(localized: "Buscando…") : String(localized: "Nenhum arquivo com esse nome"))
        case .windows: String(localized: "Nenhuma janela aberta com esse nome")
        case .all: String(localized: "Nada encontrado")
        }
    }

    /// The keys, as Raycast shows them: what Return does to the selected row, ⌘K, and Esc.
    private var footer: some View {
        HStack(spacing: 14) {
            Spacer()
            if let item = search.selectedItem {
                FooterKey(label: item.verb ?? String(localized: "Abrir"), keys: ["↩"], emphasized: true)
                FooterKey(label: String(localized: "Mais ações"), keys: ["⌘", "K"])
            }
            FooterKey(label: search.mode == .all ? String(localized: "Fechar") : String(localized: "Voltar"), keys: ["esc"])
        }
        .padding(.horizontal, NotchOpenContent.inset + 6)
        .frame(height: 32)
        .overlay(alignment: .top) {
            Rectangle().fill(NotchStyle.separator).frame(height: 1)
        }
        .padding(.bottom, 6)
    }

    /// The keys listed next to each ⌘K action work straight from the list: ⌘C, ⌘⇧C,
    /// ⌘Q… ⌘↩ falls back to the first action when none claims it. The field keeps the
    /// text-editing ones (⌘A, ⌘X, ⌘V, ⌘Z).
    private func runShortcut(_ press: KeyPress) -> Bool {
        guard press.modifiers.contains(.command), search.editing == nil, let item = search.selectedItem else { return false }
        let key: String
        switch press.key {
        case .return: key = "↩"
        case .delete: key = "⌫"
        default:
            guard let character = press.characters.first, character.isLetter || character.isNumber else { return false }
            key = String(character).uppercased()
        }
        guard !["A", "X", "V", "Z", "K"].contains(key) || press.modifiers.contains(.shift) else { return false }
        let shortcut = "⌘" + (press.modifiers.contains(.shift) ? "⇧" : "") + key
        let actions = search.actions(for: item).dropFirst()
        if let action = actions.first(where: { $0.shortcut == shortcut }) ?? (shortcut == "⌘↩" ? actions.first : nil) {
            perform(action, of: item)
            return true
        }
        return false
    }

    private func runSelected() {
        guard let item = search.selectedItem else { return }
        if search.showsActions {
            let actions = search.actions(for: item)
            if actions.indices.contains(search.actionSelection) { perform(actions[search.actionSelection], of: item) }
        } else {
            perform(item)
        }
    }

    private func perform(_ item: SearchItem) {
        handle(search.run(item))
    }

    private func perform(_ action: SearchAction, of item: SearchItem) {
        handle(search.run(action, of: item))
    }

    private func handle(_ outcome: SearchItem.Outcome) {
        switch outcome {
        case .close: controller.closeSearch(paste: false)
        case .closeAndPaste: controller.closeSearch(paste: true)
        case .openTab(let tab):
            withAnimation(NotchController.searchResize) {
                state.showsSearch = false
                state.tab = tab
            }
        case .mode(let mode):
            search.setMode(mode)
        case .review(let review):
            state.review(review)
        case .edit(let editing):
            search.beginEditing(editing)
        case .fill(let text):
            search.query = text
        case .stay:
            break
        }
    }
}
