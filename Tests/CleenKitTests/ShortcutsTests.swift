import Foundation
import Testing
@testable import CleenKit

struct ShortcutsTests {
    @Test func listWithIdentifiers() {
        let output = """
        Take a Break (1CDF81F7-F5BE-4322-B001-6FA24AC51766)
        What’s a shortcut? (8E9D41BC-B8F8-4040-8B2E-0A414B212267)
        Resize (small) (716D6B38-CA2C-4864-9B4F-6BE1E9A27EC9)

        """
        #expect(ShortcutsCLI.parseList(output) == [
            ShortcutEntry(id: "1CDF81F7-F5BE-4322-B001-6FA24AC51766", name: "Take a Break"),
            ShortcutEntry(id: "8E9D41BC-B8F8-4040-8B2E-0A414B212267", name: "What’s a shortcut?"),
            ShortcutEntry(id: "716D6B38-CA2C-4864-9B4F-6BE1E9A27EC9", name: "Resize (small)"),
        ])
    }

    @Test func listWithoutIdentifiersFallsBackToName() {
        #expect(ShortcutsCLI.parseList("Novo Atalho\nResize (small)\n") == [
            ShortcutEntry(id: "Novo Atalho", name: "Novo Atalho"),
            ShortcutEntry(id: "Resize (small)", name: "Resize (small)"),
        ])
        #expect(ShortcutsCLI.parseList("").isEmpty)
    }

    @Test func failureSummaries() {
        #expect(ShortcutsCLI.failureSummary(
            stderr: "Error: The operation couldn’t be completed. (WFBackgroundShortcutRunnerErrorDomain error 1.)\n",
            status: 1
        ) == "The operation couldn’t be completed.")
        #expect(ShortcutsCLI.failureSummary(stderr: "Error: Couldn’t find shortcut\nmore detail", status: 1) == "Couldn’t find shortcut")
        #expect(ShortcutsCLI.failureSummary(stderr: "  \n", status: 3) == "Terminou com código 3.")
        #expect(ShortcutsCLI.failureSummary(stderr: String(repeating: "x", count: 300), status: 1).count == 140)
    }

    @Test func openURLEncodesQuerySyntax() {
        let url = ShortcutsCLI.openURL(name: "Café & Pão = 2+2 #1")
        #expect(url.absoluteString == "shortcuts://open-shortcut?name=Caf%C3%A9%20%26%20P%C3%A3o%20%3D%202%2B2%20%231")
    }

    @Test func arrangedPinsFirstAndFiltersFolders() {
        let a = ShortcutEntry(id: "a", name: "Alfa")
        let b = ShortcutEntry(id: "b", name: "Beta")
        let c = ShortcutEntry(id: "c", name: "Gama")
        let library = ShortcutLibrary(shortcuts: [a, b, c], folders: [ShortcutFolder(id: "f", name: "Trabalho", memberIDs: ["a", "c"])])
        #expect(library.arranged(pinned: ["c"]) == [c, a, b])
        #expect(library.arranged(pinned: [], folderID: "f") == [a, c])
        #expect(library.arranged(pinned: [], folderID: "gone") == [a, b, c])
    }

    @Test func searchIsAccentInsensitiveAndRanked() {
        let water = ShortcutEntry(id: "1", name: "Beber água")
        let coffee = ShortcutEntry(id: "2", name: "Hora do café")
        let agenda = ShortcutEntry(id: "3", name: "Agenda de hoje")
        let paused = ShortcutEntry(id: "4", name: "Pagar contas")
        let library = ShortcutLibrary(shortcuts: [water, coffee, agenda, paused])
        // "ag": start of name beats start of a word, which beats the middle ("Pagar").
        #expect(library.arranged(pinned: [], query: "ag") == [agenda, water, paused])
        #expect(library.arranged(pinned: [], query: "CAFE") == [coffee])
        #expect(library.arranged(pinned: [], query: "  ") == [water, coffee, agenda, paused])
        #expect(library.arranged(pinned: [], query: "zzz").isEmpty)
        // Pinned wins only within the same rank.
        #expect(library.arranged(pinned: ["4"], query: "ag") == [agenda, water, paused])
    }

    @Test func glyphsAreStableAndMeaningful() {
        let one = ShortcutGlyph(name: "Novo Atalho", paletteCount: 9)
        #expect(one == ShortcutGlyph(name: "Novo Atalho", paletteCount: 9))
        #expect((0..<9).contains(one.colorIndex))
        #expect(ShortcutGlyph.fallbackSymbols.contains(one.symbol))
        #expect(ShortcutGlyph(name: "Shazam shortcut", paletteCount: 9).symbol == "music.note")
        #expect(ShortcutGlyph(name: "Mandar texto", paletteCount: 9).symbol == "text.bubble")
        // The first matching meaning wins.
        #expect(ShortcutGlyph(name: "Text Last Image", paletteCount: 9).symbol == "photo")
        #expect(ShortcutGlyph(name: "Take a Break", paletteCount: 9).symbol == "cup.and.saucer")
        #expect(ShortcutGlyph(name: "Beber Água", paletteCount: 9).symbol == "drop")
        // Short keys only match whole words.
        #expect(ShortcutGlyph(name: "Cartão", paletteCount: 9).symbol != "car")
        #expect(ShortcutGlyph(name: "Abrir car", paletteCount: 9).symbol == "car")
        #expect(ShortcutGlyph(name: "x", paletteCount: 0).colorIndex == 0)
    }
}
