import Foundation

struct Screenshot: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let date: Date
    /// Taken with ⌃ (to the clipboard): Cleen keeps its own copy so the actions work.
    let fromClipboard: Bool
}
