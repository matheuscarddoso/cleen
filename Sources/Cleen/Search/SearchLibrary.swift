import CleenKit
import Foundation
import Observation

/// What the person added to the search: quick links, snippets, and an alias or global
/// shortcut on any command. Kept in UserDefaults; edited in Ajustes › Busca and from ⌘K.
@Observable
final class SearchLibrary {
    private(set) var quicklinks: [Quicklink]
    private(set) var snippets: [Snippet]
    /// Item id → alias ("cl" for the clipboard history).
    private(set) var aliases: [String: String]
    /// Item id → its global shortcut.
    private(set) var hotKeys: [String: KeyCombo]
    /// Item id → the name it was given that shortcut under, for the list in Ajustes
    /// (the item itself may not be loaded there).
    private(set) var hotKeyTitles: [String: String]
    /// Typing a snippet's keyword anywhere replaces it with the snippet.
    var expandsSnippets: Bool {
        didSet { defaults.set(expandsSnippets, forKey: Keys.expands) }
    }

    @ObservationIgnored var onHotKeysChange: () -> Void = {}
    @ObservationIgnored var onSnippetsChange: () -> Void = {}
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let quicklinks = "search.quicklinks"
        static let snippets = "search.snippets"
        static let aliases = "search.aliases"
        static let hotKeys = "search.hotKeys"
        static let hotKeyTitles = "search.hotKeyTitles"
        static let expands = "search.expandsSnippets"
    }

    init() {
        quicklinks = Self.load([Quicklink].self, Keys.quicklinks) ?? Quicklink.defaults
        snippets = Self.load([Snippet].self, Keys.snippets) ?? Snippet.examples
        aliases = Self.load([String: String].self, Keys.aliases) ?? [:]
        hotKeys = Self.load([String: KeyCombo].self, Keys.hotKeys) ?? [:]
        hotKeyTitles = Self.load([String: String].self, Keys.hotKeyTitles) ?? [:]
        defaults.register(defaults: [Keys.expands: true])
        expandsSnippets = defaults.bool(forKey: Keys.expands)
    }

    // MARK: Quick links

    func save(_ link: Quicklink) {
        if let index = quicklinks.firstIndex(where: { $0.id == link.id }) { quicklinks[index] = link } else { quicklinks.append(link) }
        store(quicklinks, Keys.quicklinks)
    }

    func remove(_ link: Quicklink) {
        quicklinks.removeAll { $0.id == link.id }
        forget("quicklink.\(link.id)")
        store(quicklinks, Keys.quicklinks)
    }

    // MARK: Snippets

    func save(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) { snippets[index] = snippet } else { snippets.append(snippet) }
        store(snippets, Keys.snippets)
        onSnippetsChange()
    }

    func remove(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        forget("snippet.\(snippet.id)")
        store(snippets, Keys.snippets)
        onSnippetsChange()
    }

    // MARK: Aliases and shortcuts

    /// An empty alias removes it. An alias belongs to one item: giving it to another
    /// takes it from the first.
    func setAlias(_ alias: String, for id: String) {
        let alias = alias.trimmingCharacters(in: .whitespaces)
        if alias.isEmpty {
            aliases[id] = nil
        } else {
            for (other, existing) in aliases where FuzzyMatch.fold(existing) == FuzzyMatch.fold(alias) { aliases[other] = nil }
            aliases[id] = alias
        }
        store(aliases, Keys.aliases)
    }

    /// The item an alias was typed for, if any.
    func item(forAlias text: String) -> String? {
        let key = FuzzyMatch.fold(text.trimmingCharacters(in: .whitespaces))
        guard !key.isEmpty else { return nil }
        return aliases.first { FuzzyMatch.fold($0.value) == key }?.key
    }

    /// nil removes it. A combination belongs to one item.
    func setHotKey(_ combo: KeyCombo?, for id: String, title: String) {
        if let combo {
            for (other, existing) in hotKeys where existing == combo { hotKeys[other] = nil }
            hotKeys[id] = combo
            hotKeyTitles[id] = title
        } else {
            hotKeys[id] = nil
            hotKeyTitles[id] = nil
        }
        store(hotKeys, Keys.hotKeys)
        store(hotKeyTitles, Keys.hotKeyTitles)
        onHotKeysChange()
    }

    private func forget(_ id: String) {
        if aliases[id] != nil { setAlias("", for: id) }
        if hotKeys[id] != nil { setHotKey(nil, for: id, title: "") }
    }

    // MARK: Storage

    private func store(_ value: some Encodable, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
