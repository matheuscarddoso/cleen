import Foundation

/// The icons, folded once for searching, so a keystroke only compares strings.
///
/// Ranking, best first: the exact name, names that start with the query, a name part
/// that starts with it ("right" in "arrow-right"), names that contain it, an old name,
/// every word matching a name part ("check circle" → "circle-check"), then tags. Ties go
/// to the shorter name, then A to Z.
public struct LucideIndex: Sendable {
    public let icons: [LucideIcon]
    private let entries: [Entry]
    private let positions: [String: Int]

    /// Everything as UTF-8 bytes: both sides are folded the same way, and comparing bytes
    /// keeps a keystroke over ~2,000 icons under a millisecond.
    private typealias Bytes = [UInt8]

    private struct Entry: Sendable {
        let name: Bytes
        /// The name without hyphens, so a pasted component name ("ArrowRight") finds it.
        let compact: Bytes
        let parts: [Bytes]
        let aliases: [Bytes]
        let tags: [Bytes]
        let tagWords: [Bytes]
        /// Tags and old names in one run, so "inside a word" is one scan per icon.
        let haystack: Bytes
    }

    public init(icons: [LucideIcon]) {
        self.icons = icons
        entries = icons.map { icon in
            let name = LucideSearch.fold(icon.name)
            let tags = icon.tags.map(LucideSearch.fold)
            let aliases = icon.aliases.map(LucideSearch.fold)
            return Entry(
                name: Bytes(name.utf8),
                compact: Bytes(name.replacing("-", with: "").utf8),
                parts: name.split(separator: "-").map { Bytes($0.utf8) },
                aliases: aliases.map { Bytes($0.utf8) },
                tags: tags.map { Bytes($0.utf8) },
                tagWords: tags.flatMap(LucideSearch.words).map { Bytes($0.utf8) },
                haystack: Bytes((tags + aliases).joined(separator: "\n").utf8)
            )
        }
        positions = Dictionary(icons.enumerated().map { ($1.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public var isEmpty: Bool { icons.isEmpty }

    public func icon(named name: String) -> LucideIcon? {
        positions[name].map { icons[$0] }
    }

    /// The matches, best first, at most `limit`. An empty query matches nothing.
    public func search(_ query: String, limit: Int = .max) -> [LucideIcon] {
        let folded = LucideSearch.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let words = LucideSearch.words(folded)
        guard !words.isEmpty, limit > 0 else { return [] }
        // "arrow right", "arrow_right" and "ArrowRight " all mean the slug arrow-right.
        let query = Query(
            slug: Bytes(words.joined(separator: "-").utf8),
            partSlug: Bytes(("-" + words.joined(separator: "-")).utf8),
            compact: Bytes(words.joined().utf8),
            phrase: Bytes(words.joined(separator: " ").utf8),
            tokens: words.map { Bytes($0.utf8) }
        )

        var scored: [(score: Int, index: Int)] = []
        for (index, entry) in entries.enumerated() {
            if let score = Self.score(entry, query) {
                scored.append((score, index))
            }
        }
        scored.sort { a, b in
            if a.score != b.score { return a.score < b.score }
            let lengthA = entries[a.index].name.count, lengthB = entries[b.index].name.count
            if lengthA != lengthB { return lengthA < lengthB }
            return a.index < b.index
        }
        return scored.prefix(limit).map { icons[$0.index] }
    }

    private struct Query {
        let slug: Bytes
        let partSlug: Bytes
        let compact: Bytes
        let phrase: Bytes
        let tokens: [Bytes]
    }

    /// Lower is better; nil when the icon doesn't match.
    private static func score(_ entry: Entry, _ query: Query) -> Int? {
        let name = entry.name
        if name == query.slug || entry.compact == query.compact { return 0 }
        if name.starts(with: query.slug) || entry.compact.starts(with: query.compact) { return 1 }
        if name.containsRun(query.partSlug) { return 2 }
        if name.containsRun(query.slug) { return 3 }
        if entry.aliases.contains(where: { $0.starts(with: query.slug) }) { return 4 }
        let tokens = query.tokens
        if tokens.count > 1, tokens.allSatisfy({ token in entry.parts.contains { $0.starts(with: token) } }) { return 5 }
        if entry.tags.contains(query.phrase) { return 6 }
        if entry.tags.contains(where: { $0.starts(with: query.phrase) }) { return 7 }
        let everyWord = tokens.allSatisfy { token in
            entry.parts.contains { $0.starts(with: token) } || entry.tagWords.contains { $0.starts(with: token) }
        }
        if everyWord { return 8 }
        // Inside a word only once the query is long enough to mean something ("cam" in
        // "webcam"); a letter or two would match half the set.
        if query.phrase.count >= 3, entry.haystack.containsRun(query.phrase) || (query.slug != query.phrase && entry.haystack.containsRun(query.slug)) {
            return 9
        }
        return nil
    }
}

private extension Array where Element == UInt8 {
    /// Whether `needle` appears anywhere in a row.
    func containsRun(_ needle: [UInt8]) -> Bool {
        guard let first = needle.first else { return true }
        guard needle.count <= count else { return false }
        return withUnsafeBufferPointer { hay in
            needle.withUnsafeBufferPointer { pin in
                var start = 0
                let last = hay.count - pin.count
                while start <= last {
                    if hay[start] == first {
                        var offset = 1
                        while offset < pin.count, hay[start + offset] == pin[offset] { offset += 1 }
                        if offset == pin.count { return true }
                    }
                    start += 1
                }
                return false
            }
        }
    }
}

public enum LucideSearch {
    /// Lowercased, without accents: names and tags are English, but what's typed may not be.
    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .cleen)
    }

    /// "ArrowRight" stays one word; "arrow right", "arrow-right", "arrow_right" are two.
    static func words(_ folded: String) -> [String] {
        folded.split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }
}

/// The icons copied last, newest first.
public enum LucideRecents {
    public static let limit = 24

    public static func record(_ name: String, in recents: [String], limit: Int = limit) -> [String] {
        Array(([name] + recents.filter { $0 != name }).prefix(limit))
    }
}
