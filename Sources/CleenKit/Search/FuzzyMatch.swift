import Foundation

/// Ranks a candidate against what was typed, the way a launcher should: a prefix beats
/// a word start, which beats a word's initials ("ms" → "Metade Superior"), which beats
/// letters merely in order. Case and accents don't matter.
public enum FuzzyMatch {
    /// 0…1, higher is better; nil when it doesn't match at all.
    public static func score(_ query: String, _ candidate: String) -> Double? {
        let query = fold(query).trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return 0.5 }
        let text = fold(candidate)
        if text == query { return 1 }
        if text.hasPrefix(query) { return 0.95 - lengthPenalty(text, query) }

        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if words.contains(where: { $0.hasPrefix(query) }) { return 0.85 - lengthPenalty(text, query) }
        // Several typed words, each starting a word of the candidate ("met esq").
        let parts = query.split(separator: " ").map(String.init)
        if parts.count > 1, parts.allSatisfy({ part in words.contains { $0.hasPrefix(part) } }) {
            return 0.8 - lengthPenalty(text, query)
        }
        let initials = String(words.compactMap(\.first))
        if query.count > 1, initials.hasPrefix(query) { return 0.75 }
        if text.contains(query) { return 0.6 - lengthPenalty(text, query) }
        if isSubsequence(query.replacingOccurrences(of: " ", with: ""), of: text) { return 0.3 }
        return nil
    }

    /// The best score over a title and its extra search words (aliases, English names).
    public static func score(_ query: String, title: String, keywords: [String]) -> Double? {
        let best = keywords.compactMap { score(query, $0).map { $0 * 0.9 } }.max()
        switch (score(query, title), best) {
        case let (title?, keyword?): return max(title, keyword)
        case let (title?, nil): return title
        case let (nil, keyword?): return keyword
        default: return nil
        }
    }

    public static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
    }

    /// Shorter candidates win ties: "Notas" before "Notas do projeto antigo".
    private static func lengthPenalty(_ text: String, _ query: String) -> Double {
        min(0.1, Double(max(0, text.count - query.count)) * 0.004)
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var index = haystack.startIndex
        for character in needle {
            guard let found = haystack[index...].firstIndex(of: character) else { return false }
            index = haystack.index(after: found)
        }
        return true
    }
}
