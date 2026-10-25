import Testing
@testable import CleenKit

struct MarkdownLineTests {
    @Test func readsTheKindsOfLine() {
        #expect(MarkdownLine("- leite").kind == .bullet)
        #expect(MarkdownLine("* leite").kind == .bullet)
        #expect(MarkdownLine("- [ ] pão").kind == .checklist(checked: false))
        #expect(MarkdownLine("- [x] pão").kind == .checklist(checked: true))
        #expect(MarkdownLine("- [ ]").kind == .checklist(checked: false))
        #expect(MarkdownLine("12. ovos").kind == .numbered(12))
        #expect(MarkdownLine("3) ovos").kind == .numbered(3))
        #expect(MarkdownLine("## Mercado").kind == .heading(level: 2))
        #expect(MarkdownLine("> citação").kind == .quote)
        #expect(MarkdownLine("-sem espaço").kind == .plain)
        #expect(MarkdownLine("#hashtag").kind == .plain)
        #expect(MarkdownLine("2024 foi bom").kind == .plain)
    }

    @Test func measuresIndentAndMarker() {
        let line = MarkdownLine("    - [ ] pão")
        #expect(line.indent == 4)
        #expect(line.markerLength == 6)
        #expect(line.prefixLength == 10)
        #expect(line.content == "pão")
        #expect(line.level == 2)
        #expect(MarkdownLine("\t- a").level == 1)
    }

    @Test func returnContinuesOrEndsTheList() {
        #expect(MarkdownLine("- leite").continuation == .insert("- "))
        #expect(MarkdownLine("  - [x] pão").continuation == .insert("  - [ ] "))
        #expect(MarkdownLine("9. ovos").continuation == .insert("10. "))
        #expect(MarkdownLine("- ").continuation == .end)
        #expect(MarkdownLine("- [ ] ").continuation == .end)
        #expect(MarkdownLine("texto").continuation == .none)
        #expect(MarkdownLine("# Título").continuation == .none)
    }

    @Test func togglesTheCheckbox() {
        #expect(MarkdownLine.togglingCheckbox("- [ ] pão") == "- [x] pão")
        #expect(MarkdownLine.togglingCheckbox("  - [x] pão") == "  - [ ] pão")
        #expect(MarkdownLine.togglingCheckbox("- pão") == nil)
    }

    @Test func switchesListStyles() {
        #expect(MarkdownLine.applying(.checklist, to: "pão") == "- [ ] pão")
        #expect(MarkdownLine.applying(.checklist, to: "- pão") == "- [ ] pão")
        #expect(MarkdownLine.applying(.checklist, to: "- [x] pão") == "pão")
        #expect(MarkdownLine.applying(.numbered, to: "  - pão", number: 3) == "  3. pão")
        #expect(MarkdownLine.applying(.bullet, to: "- pão") == "pão")
    }

    @Test func expandsTheCheckboxShortcut() {
        #expect(MarkdownLine.expandingShortcut("[] ") == "- [ ] ")
        #expect(MarkdownLine.expandingShortcut("  [ ] ") == "  - [ ] ")
        #expect(MarkdownLine.expandingShortcut("[x] ") == "- [x] ")
        #expect(MarkdownLine.expandingShortcut("a [] ") == nil)
    }

    @Test func titleSkipsTheMarker() {
        #expect(QuickNote(text: "# Mercado\n- leite").title == "Mercado")
        #expect(QuickNote(text: "- [ ] \n- [ ] pão").title == "pão")
    }
}
