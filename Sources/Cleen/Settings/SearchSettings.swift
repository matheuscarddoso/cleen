import CleenKit
import SwiftUI

/// Ajustes › Busca: the quick links, the snippets, and the aliases and shortcuts given to
/// commands. New aliases and shortcuts are given from the search itself (⌘K).
struct SearchSettings: View {
    @Environment(SearchModel.self) private var search
    @Environment(NotchState.self) private var notch
    /// The link or snippet open for editing (a new one has an id not yet saved).
    @State private var editingLink: Quicklink?
    @State private var editingSnippet: Snippet?

    private var library: SearchLibrary { search.library }

    var body: some View {
        @Bindable var library = search.library
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                SettingRow(title: String(localized: "Expandir snippets ao digitar"), note: String(localized: "Digitar a palavra-chave de um snippet em qualquer app troca pelo texto. Usa a permissão de Acessibilidade.")) {
                    NotchSwitch(label: String(localized: "Expandir snippets"), isOn: $library.expandsSnippets)
                }
            }

            heading(String(localized: "LINKS RÁPIDOS"))
            NotchGroup {
                ForEach(library.quicklinks) { link in
                    if editingLink?.id == link.id, let draft = editingLink {
                        QuicklinkEditor(link: draft, onSave: save, onCancel: { editingLink = nil })
                    } else {
                        listRow(title: link.name, note: [link.keyword, URL(string: link.url)?.host()].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                symbol: "link", edit: { editingLink = link }, remove: { review(link) })
                    }
                }
                if let draft = editingLink, !library.quicklinks.contains(where: { $0.id == draft.id }) {
                    QuicklinkEditor(link: draft, onSave: save, onCancel: { editingLink = nil })
                } else {
                    addRow(String(localized: "Novo link rápido")) { editingLink = Quicklink(name: "", keyword: "", url: "https://") }
                }
            }

            heading(String(localized: "SNIPPETS"))
            NotchGroup {
                ForEach(library.snippets) { snippet in
                    if editingSnippet?.id == snippet.id, let draft = editingSnippet {
                        SnippetEditor(snippet: draft, onSave: save, onCancel: { editingSnippet = nil })
                    } else {
                        listRow(title: snippet.name, note: [snippet.keyword, snippet.text.split(whereSeparator: \.isNewline).first.map(String.init)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                symbol: "text.quote", edit: { editingSnippet = snippet }, remove: { review(snippet) })
                    }
                }
                if let draft = editingSnippet, !library.snippets.contains(where: { $0.id == draft.id }) {
                    SnippetEditor(snippet: draft, onSave: save, onCancel: { editingSnippet = nil })
                } else {
                    addRow(String(localized: "Novo snippet")) { editingSnippet = Snippet(name: "", keyword: ";", text: "") }
                }
            }

            heading(String(localized: "APELIDOS E ATALHOS"))
            NotchGroup {
                let ids = Set(library.aliases.keys).union(library.hotKeys.keys).sorted { search.title(for: $0).localizedStandardCompare(search.title(for: $1)) == .orderedAscending }
                ForEach(ids, id: \.self) { id in
                    SettingRow(title: search.title(for: id), note: library.aliases[id].map { String(localized: "Apelido: \($0)") }) {
                        HStack(spacing: 8) {
                            if let combo = library.hotKeys[id] {
                                Text(combo.display)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(NotchStyle.secondary)
                                    .padding(.horizontal, 6)
                                    .frame(height: 20)
                                    .background(NotchStyle.control, in: .rect(cornerRadius: 5, style: .continuous))
                            }
                            NotchIconButton(symbol: "trash", help: String(localized: "Tirar o apelido e o atalho")) { reviewCustomization(id) }
                        }
                    }
                }
                SettingRow(title: String(localized: "Para dar um apelido ou atalho"), note: String(localized: "Na busca (⌥Espaço), selecione o item e aperte ⌘K. Funciona com apps, comandos, abas, links e snippets.")) {
                    EmptyView()
                }
            }
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(NotchStyle.tertiary)
            .padding(.leading, 4)
            .padding(.top, 4)
    }

    private func listRow(title: String, note: String, symbol: String, edit: @escaping () -> Void, remove: @escaping () -> Void) -> some View {
        SettingRow(title: title, note: note.isEmpty ? nil : note) {
            HStack(spacing: 6) {
                NotchIconButton(symbol: "pencil", help: String(localized: "Editar"), action: edit)
                NotchIconButton(symbol: "trash", help: String(localized: "Apagar"), action: remove)
            }
        }
    }

    private func addRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .foregroundStyle(NotchStyle.secondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func save(_ link: Quicklink) {
        library.save(link)
        editingLink = nil
    }

    private func save(_ snippet: Snippet) {
        library.save(snippet)
        editingSnippet = nil
    }

    private func review(_ link: Quicklink) {
        notch.review(DeletionReview(
            title: String(localized: "Apagar o link rápido?"),
            items: [DeletionReview.Item(id: link.id.uuidString, name: link.name, detail: link.url, symbol: "link")],
            outcome: .delete,
            confirm: { library.remove(link) }
        ))
    }

    private func review(_ snippet: Snippet) {
        notch.review(DeletionReview(
            title: String(localized: "Apagar o snippet?"),
            items: [DeletionReview.Item(id: snippet.id.uuidString, name: snippet.name, detail: snippet.keyword, symbol: "text.quote")],
            outcome: .delete,
            confirm: { library.remove(snippet) }
        ))
    }

    private func reviewCustomization(_ id: String) {
        let title = search.title(for: id)
        let parts = [library.aliases[id].map { String(localized: "Apelido \($0)") }, library.hotKeys[id].map { String(localized: "Atalho \($0.display)") }].compactMap { $0 }
        notch.review(DeletionReview(
            title: String(localized: "Tirar de \(title)?"),
            items: [DeletionReview.Item(id: id, name: title, detail: parts.joined(separator: " · "), symbol: "command")],
            outcome: .action(String(localized: "O item continua na busca, só sem o apelido e o atalho.")),
            confirm: {
                library.setAlias("", for: id)
                library.setHotKey(nil, for: id, title: title)
            }
        ))
    }
}
