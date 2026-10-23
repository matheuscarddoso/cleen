import Foundation
import Testing
@testable import CleenKit

struct EmojiSearchTests {
    private let items = [
        EmojiItem(emoji: "😂", name: "Rosto chorando de rir", keywords: ["engraçado", "lol", "e"]),
        EmojiItem(emoji: "❤️", name: "Coração vermelho", keywords: ["amor"]),
        EmojiItem(emoji: "💔", name: "Coração partido", keywords: ["término"]),
        EmojiItem(emoji: "🥰", name: "Rosto sorridente com 3 corações", keywords: ["amor", "apaixonado"]),
    ]

    @Test func foldsCaseAndAccents() {
        #expect(EmojiSearch.search("CORAÇ", in: items).map(\.emoji) == ["❤️", "💔", "🥰"])
        #expect(EmojiSearch.search("engracado", in: items).map(\.emoji) == ["😂"])
    }

    @Test func nameMatchesRankAboveKeywords() {
        // "amor" is only a keyword for both, so picker order holds; "rosto" leads 😂's name.
        #expect(EmojiSearch.search("amor", in: items).map(\.emoji) == ["❤️", "🥰"])
        #expect(EmojiSearch.search("rosto", in: items).map(\.emoji) == ["😂", "🥰"])
    }

    @Test func everyWordHasToMatch() {
        #expect(EmojiSearch.search("coração part", in: items).map(\.emoji) == ["💔"])
        #expect(EmojiSearch.search("coração xyz", in: items).isEmpty)
    }

    @Test func emptyQueryKeepsEverything() {
        #expect(EmojiSearch.search("  ", in: items) == items)
    }

    @Test func typingTheEmojiFindsIt() {
        #expect(EmojiSearch.search("💔", in: items).map(\.emoji) == ["💔"])
    }

    @Test func oneLetterKeywordsAreDropped() {
        #expect(!items[0].terms.contains("e"))
        #expect(items[0].terms.prefix(4) == ["rosto", "chorando", "de", "rir"])
    }
}

struct EmojiRecentsTests {
    @Test func newestFirstWithoutDuplicates() {
        #expect(EmojiRecents.record("😀", in: ["🙂", "😀", "🎉"]) == ["😀", "🙂", "🎉"])
    }

    @Test func capsTheList() {
        let full = (0..<30).map(String.init)
        let recorded = EmojiRecents.record("🎉", in: full)
        #expect(recorded.count == EmojiRecents.limit)
        #expect(recorded.first == "🎉")
    }
}

struct EmojiLibraryTests {
    @Test func loadsSmileysFirstWithNames() throws {
        let sections = EmojiLibrary.load(locale: "pt_BR")
        let first = try #require(sections.first)
        #expect(!first.items.isEmpty)
        #expect(first.items.allSatisfy { !$0.name.isEmpty })
        if first.category == .people {
            #expect(first.items.first?.emoji == "😀")
            #expect(sections.map(\.category).last == .flags)
            let laughing = try #require(first.items.first { $0.emoji == "😂" })
            #expect(EmojiSearch.search("rir", in: first.items).contains(laughing))
        }
    }

    @Test func fallbackCoversCommonEmoji() {
        let items = EmojiLibrary.unicodeFallback(locale: "pt_BR")
        #expect(items.contains { $0.emoji == "😀" })
        #expect(!items.contains { $0.emoji == "🇦" })
    }
}
