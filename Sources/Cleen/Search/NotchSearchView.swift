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
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                TextField("Buscar apps, janelas, emoji, cálculos…", text: $search.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
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
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke) }

            results
        }
        .onAppear { focused = true }
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
                    LazyVStack(alignment: .leading, spacing: 1) {
                        let selectedID = search.selectedItem?.id
                        ForEach(search.sections) { section in
                            Text(section.title)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(NotchStyle.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                            ForEach(section.items) { item in
                                SearchRow(item: item, isSelected: item.id == selectedID)
                                    .id(item.id)
                                    .onTapGesture { perform(item) }
                                    .onHover { hovering in if hovering, let index = search.items.firstIndex(where: { $0.id == item.id }) { search.selection = index } }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
                .scrollEdgeFade()
                .onChange(of: search.selection) {
                    if let id = search.selectedItem?.id { proxy.scrollTo(id) }
                }
            }
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
            state.showsSearch = false
            state.tab = tab
        case .stay: break
        }
    }
}
