import Foundation

/// One shortcut from the person's library, as `shortcuts list --show-identifiers` gives it.
public struct ShortcutEntry: Sendable, Hashable, Identifiable {
    /// The shortcut's UUID when the CLI printed one, otherwise its name. Runs and
    /// favorites go by this, so two shortcuts with the same name stay distinct and a
    /// renamed one keeps its pin.
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A Shortcuts folder and the shortcuts in it.
public struct ShortcutFolder: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let memberIDs: Set<String>

    public init(id: String, name: String, memberIDs: Set<String>) {
        self.id = id
        self.name = name
        self.memberIDs = memberIDs
    }
}

/// Everything the tab shows: the shortcuts in the order the Shortcuts app keeps them,
/// and the folders that group them.
public struct ShortcutLibrary: Sendable, Equatable {
    public let shortcuts: [ShortcutEntry]
    public let folders: [ShortcutFolder]

    public init(shortcuts: [ShortcutEntry], folders: [ShortcutFolder] = []) {
        self.shortcuts = shortcuts
        self.folders = folders
    }

    /// What the grid shows: limited to a folder and a search, pinned shortcuts first.
    /// With a search, better matches come first (start of the name, then start of a
    /// word, then anywhere), pinned first within each.
    public func arranged(pinned: Set<String>, query: String = "", folderID: String? = nil) -> [ShortcutEntry] {
        let folder = folderID.flatMap { id in folders.first { $0.id == id } }
        let needle = ShortcutText.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let ranked = shortcuts.enumerated().compactMap { index, entry -> (rank: Int, pin: Int, index: Int, entry: ShortcutEntry)? in
            if let folder, !folder.memberIDs.contains(entry.id) { return nil }
            guard let rank = ShortcutText.matchRank(of: needle, in: entry.name) else { return nil }
            return (rank, pinned.contains(entry.id) ? 0 : 1, index, entry)
        }
        return ranked
            .sorted { ($0.rank, $0.pin, $0.index) < ($1.rank, $1.pin, $1.index) }
            .map(\.entry)
    }
}

/// Case- and accent-insensitive matching, so "cafe" finds "Café" and "agua" finds "Água".
enum ShortcutText {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "pt_BR"))
            .replacing("’", with: "'")
    }

    /// The words of a name, split on anything that isn't a letter or digit.
    static func words(_ text: String) -> [Substring] {
        normalized(text).split { !$0.isLetter && !$0.isNumber }
    }

    /// 0 = the name starts with the query, 1 = a word does, 2 = it's somewhere inside,
    /// nil = no match. An empty query matches everything equally.
    static func matchRank(of normalizedQuery: String, in name: String) -> Int? {
        guard !normalizedQuery.isEmpty else { return 0 }
        let haystack = normalized(name)
        if haystack.hasPrefix(normalizedQuery) { return 0 }
        if words(name).contains(where: { $0.hasPrefix(normalizedQuery) }) { return 1 }
        if haystack.contains(normalizedQuery) { return 2 }
        return nil
    }
}
