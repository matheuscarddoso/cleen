import AppKit
import SwiftUI

/// One row of the search: what it's called, how it looks, and what Return does.
struct SearchItem: Identifiable {
    enum Icon {
        case symbol(String, Color)
        case app(URL)
        case emoji(String)
        case color(NSColor)
        case text(String)
    }

    /// What happens to the notch after the action runs.
    enum Outcome {
        /// Closes, handing the keyboard back to the app you were in.
        case close
        /// Closes, then pastes what the action put on the clipboard into that app.
        case closeAndPaste
        /// Leaves the search for a tab of the notch.
        case openTab(NotchTab)
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
    let action: @MainActor () -> Outcome
}

struct SearchSection: Identifiable {
    let title: String
    let items: [SearchItem]
    var id: String { title }
}
