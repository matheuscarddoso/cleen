import AppKit
import CleenKit
import SwiftUI

/// One row of the search: what it's called, how it looks, what Return does, and what
/// else it can do (the ⌘K panel).
struct SearchItem: Identifiable {
    enum Icon {
        case symbol(String, Color)
        case app(URL)
        /// A file or folder: its Finder icon.
        case file(URL)
        case emoji(String)
        case color(NSColor)
        case text(String)
        case lucide(LucideIcon)
    }

    /// What happens to the notch after the action runs.
    enum Outcome {
        /// Closes, handing the keyboard back to the app you were in.
        case close
        /// Closes, then pastes what the action put on the clipboard into that app.
        case closeAndPaste
        /// Leaves the search for a tab of the notch.
        case openTab(NotchTab)
        /// Narrows the search to one kind of result (files, open windows).
        case mode(SearchModel.Mode)
        /// Something to confirm first: the panel grows into the review.
        case review(DeletionReview)
        /// The ⌘K panel switches to naming the item or recording its shortcut.
        case edit(SearchModel.Editing)
        /// Puts this text in the field ("gh " for a quick link that needs a query).
        case fill(String)
        case stay
    }

    let id: String
    let title: String
    var subtitle: String?
    let icon: Icon
    /// Words that find it besides the title (English names, aliases).
    var keywords: [String] = []
    /// The grey word on the right: "App", "Janela", "Comando".
    var kind: String?
    /// The verb on Return, in the bar at the bottom: "Abrir", "Colar", "Executar".
    var verb: String?
    /// The other things it can do, listed by ⌘K; the first also runs on ⌘Return.
    var actions: [SearchAction] = []
    /// Whether it can get an alias and a global shortcut: only what's found the same way
    /// every time (apps, commands, tabs, links), not one-off results like a calculation.
    var isCustomizable = false
    let action: @MainActor () -> Outcome
}

/// One entry of the ⌘K panel.
struct SearchAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    /// The keys that run it straight from the list: "⌘↩", "⌘⇧C".
    var shortcut: String?
    var isDestructive = false
    let run: @MainActor () -> SearchItem.Outcome

    init(_ title: String, symbol: String, id: String? = nil, shortcut: String? = nil, isDestructive: Bool = false, run: @escaping @MainActor () -> SearchItem.Outcome) {
        self.id = id ?? title
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.isDestructive = isDestructive
        self.run = run
    }
}

struct SearchSection: Identifiable {
    let title: String
    let items: [SearchItem]
    var id: String { title }
}
