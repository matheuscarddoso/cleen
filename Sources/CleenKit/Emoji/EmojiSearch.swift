import Foundation

/// Finding emoji by what you'd call them, ignoring case and accents ("coracao" finds
/// "coração"). Every word typed has to match the start of some word of the emoji.
public enum EmojiSearch {
    /// Lowercased, accent-free words: "Rosto Chorando, de rir!" → ["rosto", "chorando", "de", "rir"].
    public static func words(in text: String) -> [String] {
        fold(text)
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
    }

    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .cleen)
    }

    /// The matches, best first: name matches before keyword matches, earlier words before
    /// later ones; ties keep the picker's order. Typing an emoji itself finds it.
    public static func search(_ query: String, in items: [EmojiItem]) -> [EmojiItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let tokens = words(in: trimmed)
        if tokens.isEmpty {
            return items.filter { $0.emoji == trimmed }
        }
        var scored: [(score: Int, index: Int, item: EmojiItem)] = []
        for (index, item) in items.enumerated() {
            if let score = score(tokens, against: item) {
                scored.append((score, index, item))
            }
        }
        scored.sort { ($0.score, $0.index) < ($1.score, $1.index) }
        return scored.map(\.item)
    }

    /// Lower is better; nil when some token matches nothing.
    static func score(_ tokens: [String], against item: EmojiItem) -> Int? {
        var total = 0
        for token in tokens {
            var best: Int?
            for (position, term) in item.terms.enumerated() where term.hasPrefix(token) {
                let isName = position < item.nameWordCount
                // Exact words beat prefixes; name words beat keywords; the name's first
                // word ("coração" in "coração vermelho") beats the rest.
                var score = isName ? position : 20 + min(position - item.nameWordCount, 40) / 4
                if term.count != token.count { score += 10 }
                best = min(best ?? .max, score)
                if score == 0 { break }
            }
            guard let best else { return nil }
            total += best
        }
        return total
    }
}

/// The last emoji you used, newest first.
public enum EmojiRecents {
    public static let limit = 24

    public static func record(_ emoji: String, in recents: [String], limit: Int = limit) -> [String] {
        Array(([emoji] + recents.filter { $0 != emoji }).prefix(limit))
    }
}
