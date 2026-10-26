import AppKit
import CleenKit
import SwiftUI

/// ⌘K over the results, as in Raycast: everything the selected row can do, with the
/// keys for each. It also hosts the two small editors it opens: the alias field and
/// the shortcut recorder.
struct SearchActionPanel: View {
    let item: SearchItem
    let actions: [SearchAction]
    let perform: (SearchAction) -> Void
    @Environment(SearchModel.self) private var search
    @State private var alias = ""
    @FocusState private var aliasFocused: Bool
    /// The pointer where it was when the panel opened: only moving it picks a row.
    @State private var restingPointer: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(NotchStyle.separator).frame(height: 1)
            switch search.editing {
            case .alias(let id, _):
                aliasEditor(id: id)
            case .hotKey(let id, _):
                recorder(id: id)
            case nil:
                list
            }
        }
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.11))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
        }
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke) }
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
        .onAppear { restingPointer = NSEvent.mouseLocation }
    }

    private var header: some View {
        Text(headerTitle)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NotchStyle.tertiary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerTitle: String {
        switch search.editing {
        case .alias(_, let title): String(localized: "Apelido para \(title)")
        case .hotKey(_, let title): String(localized: "Atalho global para \(title)")
        case nil: item.title
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button { perform(action) } label: {
                    HStack(spacing: 9) {
                        Image(systemName: action.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(action.isDestructive ? NotchStyle.critical : NotchStyle.secondary)
                            .frame(width: 16)
                        Text(action.title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(action.isDestructive ? NotchStyle.critical : NotchStyle.primary)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if let shortcut = action.shortcut {
                            Text(shortcut)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(NotchStyle.tertiary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(index == search.actionSelection ? NotchStyle.selection : .clear, in: .rect(cornerRadius: 7, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    let pointer = NSEvent.mouseLocation
                    guard hovering, pointer != restingPointer else { return }
                    restingPointer = nil
                    search.actionSelection = index
                }
            }
        }
        .padding(5)
    }

    private func aliasEditor(id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("ex.: cl", text: $alias)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .focused($aliasFocused)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(NotchStyle.control, in: .rect(cornerRadius: 7, style: .continuous))
                .onSubmit { search.saveAlias(alias) }
            Text("Digitar o apelido inteiro põe isto em primeiro. ↩ salva, vazio tira, esc volta.")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .onAppear {
            alias = search.library.aliases[id] ?? ""
            aliasFocused = true
        }
    }

    private func recorder(id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                if let combo = search.library.hotKeys[id] {
                    ForEach(combo.keycaps, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NotchStyle.primary)
                            .frame(minWidth: 26, minHeight: 26)
                            .padding(.horizontal, key.count > 1 ? 5 : 0)
                            .background(NotchStyle.control, in: .rect(cornerRadius: 6, style: .continuous))
                    }
                } else {
                    Text("Pressione as teclas…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(NotchStyle.card, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(NotchStyle.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])) }
            Text(search.recorderMessage ?? String(localized: "Funciona em qualquer app, com o Cleen fechado. ⌫ tira, esc volta."))
                .font(.system(size: 11))
                .foregroundStyle(search.recorderMessage == nil ? NotchStyle.secondary : NotchStyle.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
    }
}
