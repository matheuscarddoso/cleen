import Foundation

/// One emoji as the picker shows and searches it.
public struct EmojiItem: Hashable, Sendable, Identifiable {
    public let emoji: String
    /// "Rosto chorando de rir", for the tooltip.
    public let name: String
    /// Folded (no case, no accents) words the search matches: the name's words first,
    /// then the system's keywords ("rir", "engraçado", "lol"…).
    public let terms: [String]

    public var id: String { emoji }

    public init(emoji: String, name: String, keywords: [String] = []) {
        self.emoji = emoji
        self.name = name
        let nameWords = EmojiSearch.words(in: name)
        var seen = Set(nameWords)
        var terms = nameWords
        // One-letter keywords ("e", "a") are articles; they'd only add noise.
        for keyword in keywords.flatMap(EmojiSearch.words(in:)) where keyword.count > 1 && seen.insert(keyword).inserted {
            terms.append(keyword)
        }
        self.terms = terms
        nameWordCount = nameWords.count
    }

    /// How many of `terms` came from the name (they rank above keywords).
    let nameWordCount: Int
}

/// The picker's groups, in the order Apple's own picker uses.
public enum EmojiCategory: String, CaseIterable, Sendable {
    case people
    case nature
    case food
    case activity
    case travel
    case objects
    case symbols
    case flags
    /// Everything when the system's categories aren't available.
    case all

    public var title: String {
        switch self {
        case .people: "Carinhas e pessoas"
        case .nature: "Animais e natureza"
        case .food: "Comidas e bebidas"
        case .activity: "Atividades"
        case .travel: "Viagens e lugares"
        case .objects: "Objetos"
        case .symbols: "Símbolos"
        case .flags: "Bandeiras"
        case .all: "Emoji"
        }
    }
}

public struct EmojiSection: Hashable, Sendable, Identifiable {
    public let category: EmojiCategory
    public let items: [EmojiItem]

    public var id: EmojiCategory { category }

    public init(category: EmojiCategory, items: [EmojiItem]) {
        self.category = category
        self.items = items
    }
}
