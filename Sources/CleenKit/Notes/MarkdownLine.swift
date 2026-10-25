import Foundation

/// One line of a quick note read as Markdown: what kind of line it is, how far it's
/// indented, and how long its marker is ("- [ ] " is 6). Notes stay plain Markdown on
/// disk; this is what the editor styles and what Return and the shortcuts act on.
///
/// Every count is in UTF-16 units, the editor's (NSString) measure. Indents and markers
/// are ASCII, so they're the same in characters.
public struct MarkdownLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case plain
        case heading(level: Int)
        case bullet
        case checklist(checked: Bool)
        case numbered(Int)
        case quote
    }

    /// The list styles the shortcuts switch a line to.
    public enum ListStyle: Sendable {
        case bullet
        case checklist
        case numbered
    }

    /// What Return does at the end of a line.
    public enum Continuation: Equatable, Sendable {
        /// An ordinary line break.
        case none
        /// A break, then this prefix: the next item of the list.
        case insert(String)
        /// The item was empty: drop its marker and leave the list.
        case end
    }

    public let kind: Kind
    /// Leading spaces and tabs.
    public let indent: Int
    /// The marker after the indent, its trailing space included.
    public let markerLength: Int
    /// The text after the marker.
    public let content: String

    /// Indent plus marker: where the words start.
    public var prefixLength: Int { indent + markerLength }

    /// Nesting depth: a tab or two spaces per level.
    public var level: Int {
        var level = 0
        var spaces = 0
        for character in leadingWhitespace {
            if character == "\t" { level += 1; spaces = 0 } else { spaces += 1; if spaces == 2 { level += 1; spaces = 0 } }
        }
        return level
    }

    public var isListItem: Bool {
        switch kind {
        case .bullet, .checklist, .numbered: true
        default: false
        }
    }

    private let leadingWhitespace: Substring

    public init(_ line: String) {
        let whitespace = line.prefix { $0 == " " || $0 == "\t" }
        leadingWhitespace = whitespace
        indent = whitespace.utf16.count
        let rest = line.dropFirst(whitespace.count)
        let parsed = Self.marker(in: rest)
        kind = parsed.kind
        markerLength = parsed.length
        content = String(rest.dropFirst(parsed.length))
    }

    private static func marker(in rest: Substring) -> (kind: Kind, length: Int) {
        let characters = Array(rest.prefix(8))
        func at(_ index: Int) -> Character? { index < characters.count ? characters[index] : nil }

        if let first = at(0), "-*+".contains(first), at(1) == " " {
            if at(2) == "[", let mark = at(3), " xX".contains(mark), at(4) == "]", at(5) == " " || at(5) == nil {
                return (.checklist(checked: mark != " "), at(5) == nil ? 5 : 6)
            }
            return (.bullet, 2)
        }
        if at(0) == ">", at(1) == " " { return (.quote, 2) }
        if at(0) == "#" {
            let hashes = rest.prefix { $0 == "#" }.count
            if hashes <= 3, rest.dropFirst(hashes).first == " " { return (.heading(level: hashes), hashes + 1) }
        }
        let digits = rest.prefix(while: \.isASCII).prefix(while: \.isNumber)
        if !digits.isEmpty, digits.count <= 3, let number = Int(digits) {
            let after = rest.dropFirst(digits.count)
            if let delimiter = after.first, delimiter == "." || delimiter == ")", after.dropFirst().first == " " {
                return (.numbered(number), digits.count + 2)
            }
        }
        return (.plain, 0)
    }

    // MARK: Editing

    /// Return at the end of this line: continue the list, or leave it from an empty item.
    public var continuation: Continuation {
        let whitespace = String(leadingWhitespace)
        let empty = content.allSatisfy(\.isWhitespace)
        switch kind {
        case .bullet:
            return empty ? .end : .insert(whitespace + "- ")
        case .checklist:
            return empty ? .end : .insert(whitespace + "- [ ] ")
        case .numbered(let number):
            return empty ? .end : .insert(whitespace + "\(number + 1). ")
        case .quote:
            return empty ? .end : .insert("> ")
        case .plain, .heading:
            return .none
        }
    }

    /// The line with its checkbox flipped; nil when it isn't a checklist item.
    public static func togglingCheckbox(_ line: String) -> String? {
        let parsed = MarkdownLine(line)
        guard case .checklist(let checked) = parsed.kind else { return nil }
        var characters = Array(line)
        // "- [" then the mark: indent + 3.
        let mark = parsed.leadingWhitespace.count + 3
        characters[mark] = checked ? " " : "x"
        return String(characters)
    }

    /// The line switched to a list style (Apple Notes' ⇧⌘L, ⇧⌘7, ⇧⌘9); applied to a line
    /// already in that style, it goes back to plain text.
    public static func applying(_ style: ListStyle, to line: String, number: Int = 1) -> String {
        let parsed = MarkdownLine(line)
        let whitespace = String(parsed.leadingWhitespace)
        let isSame = switch (style, parsed.kind) {
        case (.bullet, .bullet), (.checklist, .checklist), (.numbered, .numbered): true
        default: false
        }
        if isSame { return whitespace + parsed.content }
        let marker = switch style {
        case .bullet: "- "
        case .checklist: "- [ ] "
        case .numbered: "\(number). "
        }
        return whitespace + marker + parsed.content
    }

    /// What typing a space just turned into, Notion-style: "[]" or "[ ]" at the start of
    /// a line becomes a checklist item, "[x]" a ticked one. `typed` is the line up to and
    /// including the space; nil when it's no shortcut.
    public static func expandingShortcut(_ typed: String) -> String? {
        let whitespace = typed.prefix { $0 == " " || $0 == "\t" }
        switch typed.dropFirst(whitespace.count) {
        case "[] ", "[ ] ": return whitespace + "- [ ] "
        case "[x] ", "[X] ": return whitespace + "- [x] "
        default: return nil
        }
    }
}
