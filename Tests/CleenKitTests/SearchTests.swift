import CoreGraphics
import Testing
@testable import CleenKit

struct FuzzyMatchTests {
    @Test func prefixBeatsWordStartBeatsInitialsBeatsScattered() throws {
        let prefix = try #require(FuzzyMatch.score("met", "Metade esquerda"))
        let wordStart = try #require(FuzzyMatch.score("esq", "Metade esquerda"))
        let initials = try #require(FuzzyMatch.score("me", "Maximizar Editor"))
        let scattered = try #require(FuzzyMatch.score("mtd", "Metade"))
        #expect(prefix > wordStart && wordStart > scattered)
        #expect(initials > scattered)
    }

    @Test func ignoresCaseAndAccents() {
        #expect(FuzzyMatch.score("area", "Área de transferência") != nil)
        #expect(FuzzyMatch.score("CALEN", "calendário") != nil)
    }

    @Test func severalWordsEachStartingAWord() {
        #expect(FuzzyMatch.score("met esq", "Metade esquerda") != nil)
        #expect(FuzzyMatch.score("xyz", "Metade esquerda") == nil)
    }

    @Test func keywordsCountButTitleWins() throws {
        let viaKeyword = try #require(FuzzyMatch.score("left", title: "Metade esquerda", keywords: ["left half"]))
        let viaTitle = try #require(FuzzyMatch.score("metade", title: "Metade esquerda", keywords: ["left half"]))
        #expect(viaTitle > viaKeyword)
    }
}

struct CalculatorTests {
    @Test(arguments: [
        ("2+2", 4.0), ("12*3,5", 42.0), ("(1 + 2) * 3", 9.0), ("2^10", 1024.0), ("-3 + 5", 2.0),
        ("200 + 15%", 230.0), ("200 - 10%", 180.0), ("10% * 50", 5.0), ("1,250 x 4", 5000.0), ("7 ÷ 2", 3.5),
    ])
    func evaluates(text: String, expected: Double) throws {
        let value = try #require(Calculator.evaluate(text))
        #expect(abs(value - expected) < 1e-9)
    }

    @Test func commaDecimalLocale() throws {
        #expect(try #require(Calculator.evaluate("1.250,5 + 1", decimalSeparator: ",")) == 1251.5)
        #expect(try #require(Calculator.evaluate("3,5 * 2", decimalSeparator: ",")) == 7)
    }

    @Test(arguments: ["42", "", "abc", "2+", "1/0", "(2+3", "rm -rf"])
    func notACalculation(text: String) {
        #expect(Calculator.evaluate(text) == nil)
    }
}

struct LoremIpsumTests {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test func startsTheClassicWay() {
        var generator = Seeded(state: 1)
        #expect(LoremIpsum.paragraphs(2, using: &generator).hasPrefix("Lorem ipsum dolor sit amet, consectetur adipiscing elit."))
        #expect(LoremIpsum.words(3, using: &generator) == "Lorem ipsum dolor")
    }

    @Test func countsComeOutRight() {
        var generator = Seeded(state: 7)
        #expect(LoremIpsum.words(12, using: &generator).split(separator: " ").count == 12)
        #expect(LoremIpsum.paragraphs(3, using: &generator).components(separatedBy: "\n\n").count == 3)
        let sentences = LoremIpsum.sentences(4, using: &generator)
        #expect(sentences.filter { $0 == "." }.count == 4)
    }
}

struct WindowLayoutTests {
    let area = CGRect(x: 0, y: 33, width: 1470, height: 900)
    let window = CGRect(x: 100, y: 100, width: 800, height: 600)

    @Test func halvesAndQuarters() {
        #expect(WindowLayout.leftHalf.frame(in: area, current: window) == CGRect(x: 0, y: 33, width: 735, height: 900))
        #expect(WindowLayout.bottomRight.frame(in: area, current: window) == CGRect(x: 735, y: 483, width: 735, height: 450))
        #expect(WindowLayout.maximize.frame(in: area, current: window) == area)
    }

    @Test func centerKeepsTheSize() {
        let centered = WindowLayout.center.frame(in: area, current: window)
        #expect(centered.size == window.size)
        #expect(centered.midX == area.midX && centered.midY == area.midY)
    }

    @Test func movingToAnotherScreenKeepsTheProportion() {
        let target = CGRect(x: -229, y: -1080, width: 1920, height: 1050)
        let moved = WindowLayout.moved(CGRect(x: 0, y: 33, width: 735, height: 900), from: area, to: target)
        #expect(abs(moved.width - 960) < 1)
        #expect(moved.minX == target.minX)
    }
}
