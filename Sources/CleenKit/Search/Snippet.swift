import Foundation

/// A piece of text kept ready to paste: found by name in the search, or typed out by its
/// keyword anywhere (`;email` becomes the address).
public struct Snippet: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var keyword: String
    public var text: String

    public init(id: UUID = UUID(), name: String, keyword: String = "", text: String) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.text = text
    }

    /// The text ready to paste: `{date}`, `{time}`, `{datetime}`, `{weekday}` and
    /// `{clipboard}` filled in. `{cursor}` marks where the cursor ends up: the answer
    /// says how many characters back from the end that is.
    public func expanded(now: Date = .now, clipboard: String? = nil, locale: Locale = .cleen) -> (text: String, cursorFromEnd: Int) {
        var text = text
        let values: [(String, String)] = [
            ("{datetime}", now.formatted(.dateTime.day().month(.twoDigits).year().hour().minute().locale(locale))),
            ("{date}", now.formatted(.dateTime.day().month(.twoDigits).year().locale(locale))),
            ("{time}", now.formatted(.dateTime.hour().minute().locale(locale))),
            ("{weekday}", now.formatted(.dateTime.weekday(.wide).locale(locale))),
            ("{clipboard}", clipboard ?? ""),
        ]
        for (placeholder, value) in values {
            text = text.replacingOccurrences(of: placeholder, with: value)
        }
        guard let cursor = text.range(of: "{cursor}") else { return (text, 0) }
        let after = text[cursor.upperBound...].replacingOccurrences(of: "{cursor}", with: "")
        text = String(text[..<cursor.lowerBound]) + after
        return (text, after.count)
    }

    /// The snippet whose keyword was just typed (the longest one, when one keyword ends
    /// another), or nil. `typed` is what was typed since the last pause in typing.
    public static func justTyped(_ typed: String, in snippets: [Snippet]) -> Snippet? {
        snippets
            .filter { $0.keyword.count >= 2 && typed.hasSuffix($0.keyword) }
            .max { $0.keyword.count < $1.keyword.count }
    }

    /// What a new install shows as an example, so the idea is clear.
    public static let examples: [Snippet] = [
        Snippet(name: String(localized: "Data de hoje"), keyword: ";hoje", text: "{date}"),
        Snippet(name: String(localized: "Saudação"), keyword: ";oi", text: String(localized: "Oi! Tudo bem? {cursor}")),
    ]
}

/// The characters typed since the last pause, as the snippet expander sees them: a
/// short rolling window that resets on anything that moves the cursor.
public struct TypedBuffer: Sendable, Equatable {
    public private(set) var text = ""
    public static let limit = 48

    public init() {}

    public mutating func append(_ characters: String) {
        text += characters
        if text.count > Self.limit { text.removeFirst(text.count - Self.limit) }
    }

    public mutating func backspace() {
        if !text.isEmpty { text.removeLast() }
    }

    public mutating func reset() { text = "" }
}
