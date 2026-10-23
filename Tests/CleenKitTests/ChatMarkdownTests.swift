import Testing
@testable import CleenKit

struct ChatMarkdownTests {
    @Test func bulletsBecomeDotsAndKeepTheirIndent() {
        #expect(ChatMarkdown.prepare("- um\n* dois\n  + três") == "• um\n• dois\n  • três")
    }

    @Test func inlineMarkupIsLeftForText() {
        let text = "**Negrito** e *itálico* com `código`."
        #expect(ChatMarkdown.prepare(text) == text)
    }

    @Test func headingsBecomeBoldLines() {
        #expect(ChatMarkdown.prepare("## Passos\nFaça isto.") == "**Passos**\nFaça isto.")
        // A hashtag isn't a heading.
        #expect(ChatMarkdown.prepare("#swift") == "#swift")
    }

    @Test func fencedCodeBecomesInlineCode() {
        let markdown = "Veja:\n```swift\nlet a = 1\n\nprint(`a`)\n```\nPronto."
        #expect(ChatMarkdown.prepare(markdown) == "Veja:\n`let a = 1`\n\nprint(`a`)\nPronto.")
    }

    @Test func rulesDisappearAndBlankLinesStay() {
        #expect(ChatMarkdown.prepare("Um\n\n---\nDois") == "Um\n\n\nDois")
    }
}
