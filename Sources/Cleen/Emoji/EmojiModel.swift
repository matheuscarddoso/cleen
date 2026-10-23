import AppKit
import CleenKit
import Observation

/// The emoji picker: the system's emoji list (read once, off the main thread), the
/// search, and the ones you used last.
///
/// One instance for the app's lifetime, so the list is read once and not on every visit.
@Observable
final class EmojiModel {
    static let shared = EmojiModel()

    private(set) var sections: [EmojiSection] = []
    private(set) var recents: [EmojiItem] = []
    /// The search's matches, best first; empty while there's no query.
    private(set) var results: [EmojiItem] = []
    var query = "" {
        didSet { if query != oldValue { updateResults() } }
    }

    @ObservationIgnored private var all: [EmojiItem] = []
    @ObservationIgnored private var byEmoji: [String: EmojiItem] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var recentEmoji: [String]

    private static let recentsKey = "emoji.recents"

    private init() {
        recentEmoji = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
    }

    var isLoaded: Bool { !sections.isEmpty }
    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    func load() async {
        if loadTask == nil {
            loadTask = Task {
                let sections = await offMain { EmojiLibrary.load() }
                self.sections = sections
                all = sections.flatMap(\.items)
                byEmoji = Dictionary(all.map { ($0.emoji, $0) }, uniquingKeysWith: { first, _ in first })
                updateRecents()
                updateResults()
            }
        }
        await loadTask?.value
    }

    /// The best matches over every emoji, for the notch search.
    func matches(_ query: String, limit: Int) -> [EmojiItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return Array(EmojiSearch.search(query, in: all).prefix(limit))
    }

    /// Remembers an emoji used from somewhere else (the search), as a pick here would.
    func noteUsed(_ item: EmojiItem) {
        recentEmoji = EmojiRecents.record(item.emoji, in: recentEmoji)
        UserDefaults.standard.set(recentEmoji, forKey: Self.recentsKey)
    }

    // MARK: Using one

    /// Copies the emoji and pastes it into the app in front. Returns whether it pasted
    /// (false without Accessibility: the emoji is still on the clipboard).
    @discardableResult
    func use(_ item: EmojiItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.emoji, forType: .string)
        // Marked transient (nspasteboard.org) so clipboard histories, Cleen's included,
        // don't fill up with every emoji picked here.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        recentEmoji = EmojiRecents.record(item.emoji, in: recentEmoji)
        UserDefaults.standard.set(recentEmoji, forKey: Self.recentsKey)
        return PasteKeystroke.send()
    }

    // MARK: Derived

    /// Shows the latest recents. Called when the tab appears, not on every pick, so the
    /// row doesn't reshuffle under the pointer while you're choosing.
    func updateRecents() {
        recents = recentEmoji.map { byEmoji[$0] ?? EmojiItem(emoji: $0, name: $0) }
    }

    private func updateResults() {
        results = isSearching ? EmojiSearch.search(query, in: all) : []
    }
}
