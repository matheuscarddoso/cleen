import Foundation

/// A quick note as the HTML the Notes app keeps in a note's body: headings, lists,
/// quotes and inline bold, italic and code come through; a task shows as ☐ or ☑, since
/// Notes' own checklists can't be made from outside it. The first line becomes the
/// Notes title, as it does when you type there.
public enum NoteHTML {
    public static func render(_ text: String) -> String {
        var html: [String] = []
        var openList: String?

        func closeList() {
            if let tag = openList { html.append("</\(tag)>") }
            openList = nil
        }

        for raw in text.components(separatedBy: "\n") {
            let line = MarkdownLine(raw)
            let content = inline(escape(line.content))
            switch line.kind {
            case .heading(let level):
                closeList()
                let level = min(max(level, 1), 3)
                html.append("<h\(level)>\(content)</h\(level)>")
            case .bullet, .numbered:
                let tag = line.kind == .bullet ? "ul" : "ol"
                if openList != tag {
                    closeList()
                    html.append("<\(tag)>")
                    openList = tag
                }
                html.append("<li>\(content)</li>")
            case .checklist(let checked):
                closeList()
                html.append("<div>\(checked ? "☑" : "☐") \(content)</div>")
            case .quote:
                closeList()
                html.append("<blockquote>\(content)</blockquote>")
            case .plain:
                closeList()
                html.append(raw.allSatisfy(\.isWhitespace) ? "<div><br></div>" : "<div>\(content)</div>")
            }
        }
        closeList()
        return html.joined()
    }

    static func escape(_ text: String) -> String {
        text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
    }

    /// `**bold**`, `*italic*` or `_italic_`, `` `code` ``.
    static func inline(_ text: String) -> String {
        text
            .replacing(/\*\*(.+?)\*\*/) { "<b>\($0.1)</b>" }
            .replacing(/\*(\S(?:.*?\S)?)\*/) { "<i>\($0.1)</i>" }
            // Only a word on its own: snake_case_names keep their underscores.
            .replacing(/(^|\W)_(\S(?:.*?\S)?)_(?=$|\W)/) { "\($0.1)<i>\($0.2)</i>" }
            .replacing(/`(.+?)`/) { "<tt>\($0.1)</tt>" }
    }
}
