import SwiftUI

/// The launcher inside the notch: a field, then results grouped by kind. Arrows move,
/// Return runs, Esc closes — it never needs the mouse.
struct NotchSearchView: View {
    let controller: NotchController
    @Environment(SearchModel.self) private var search
    @Environment(NotchState.self) private var state
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var search = search
        VStack(spacing: 0) {
            // Raycast's layout: the field bare on top, a hairline, the list, and a bar of
            // keys at the bottom. Nothing boxed, so the rows get the room.
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                TextField("Buscar apps, janelas, emoji, cálculos…", text: $search.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17))
                    .focused($focused)
                    .onSubmit(runSelected)
                    .onKeyPress(.downArrow) { search.move(1); return .handled }
                    .onKeyPress(.upArrow) { search.move(-1); return .handled }
                    .onKeyPress(.tab) { search.move(1); return .handled }
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

            footer
        }
        .onAppear { focused = true }
        .onChange(of: state.searchFocusRequest) { focused = true }
    }

    @ViewBuilder
    private var results: some View {
        if search.sections.isEmpty {
            Text("Nada encontrado")
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
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 3)
                            ForEach(section.items) { item in
                                SearchRow(item: item, isSelected: item.id == selectedID)
                                    .id(item.id)
                                    .onTapGesture { perform(item) }
                                    .onHover { hovering in if hovering, let index = search.items.firstIndex(where: { $0.id == item.id }) { search.selection = index } }
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

    /// The keys, as Raycast shows them: what Return does to the selected row, and Esc.
    private var footer: some View {
        HStack(spacing: 14) {
            Spacer()
            if let item = search.selectedItem {
                FooterKey(label: actionLabel(for: item), keys: ["⏎"], emphasized: true)
            }
            FooterKey(label: String(localized: "Mover"), keys: ["↑", "↓"])
            FooterKey(label: String(localized: "Fechar"), keys: ["esc"])
        }
        .padding(.horizontal, NotchOpenContent.inset + 6)
        .frame(height: 32)
        .overlay(alignment: .top) {
            Rectangle().fill(NotchStyle.separator).frame(height: 1)
        }
        .padding(.bottom, 6)
    }

    /// Return's verb for a row: the kinds that already read as one stay as they are.
    private func actionLabel(for item: SearchItem) -> String {
        switch item.kind {
        case String(localized: "App"), String(localized: "Cleen"): String(localized: "Abrir")
        case String(localized: "Janela"): String(localized: "Ajustar janela")
        case String(localized: "Comando"): String(localized: "Executar")
        case let kind?: kind
        case nil: String(localized: "Abrir")
        }
    }

    private func runSelected() {
        if let item = search.selectedItem { perform(item) }
    }

    private func perform(_ item: SearchItem) {
        switch search.run(item) {
        case .close: controller.closeSearch(paste: false)
        case .closeAndPaste: controller.closeSearch(paste: true)
        case .openTab(let tab):
            withAnimation(NotchController.searchResize) {
                state.showsSearch = false
                state.tab = tab
            }
        case .stay: break
        }
    }
}
