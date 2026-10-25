import Foundation
import Testing
@testable import CleenKit

struct NoteSyncTests {
    private let past = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    private func note(_ text: String, id: UUID = UUID(), at date: Date? = nil) -> QuickNote {
        QuickNote(id: id, text: text, updatedAt: date ?? past)
    }

    @Test func aNewNoteBecomesAFileNamedAfterItsTitle() {
        let shopping = note("# Lista do mercado\n- [ ] café")
        let plan = NoteFileSync.plan(notes: [shopping, note("  \n")], files: [], index: [:])
        #expect(plan.writes == ["Lista do mercado.md": shopping.text])
        #expect(plan.index[shopping.id]?.fileName == "Lista do mercado.md")
    }

    @Test func aNamesakeGetsANumber() {
        let file = NoteFileSync.File(name: "Ideias.md", text: "outra coisa", modified: past)
        let mine = note("Ideias\nnovas")
        let plan = NoteFileSync.plan(notes: [mine], files: [file], index: [:])
        #expect(plan.index[mine.id]?.fileName == "Ideias 2.md")
        // The file nobody knew comes in as a note of its own.
        #expect(plan.imports.values.contains("outra coisa"))
    }

    @Test func anEditInTheVaultComesHere() {
        let id = UUID()
        let index: NoteFileSync.Index = [id: .init(fileName: "Mercado.md", syncedText: "Mercado\n- pão")]
        let file = NoteFileSync.File(name: "Mercado.md", text: "Mercado\n- pão\n- leite", modified: later)
        let plan = NoteFileSync.plan(notes: [note("Mercado\n- pão", id: id)], files: [file], index: index)
        #expect(plan.updates == [id: "Mercado\n- pão\n- leite"])
        #expect(plan.writes.isEmpty)
    }

    @Test func anEditHereGoesToTheFileAndItsNameFollowsTheTitle() {
        let id = UUID()
        let index: NoteFileSync.Index = [id: .init(fileName: "Lis.md", syncedText: "Lis")]
        let file = NoteFileSync.File(name: "Lis.md", text: "Lis", modified: past)
        let plan = NoteFileSync.plan(notes: [note("Lista", id: id, at: later)], files: [file], index: index)
        #expect(plan.renames == ["Lis.md": "Lista.md"])
        #expect(plan.writes == ["Lista.md": "Lista"])
    }

    @Test func aFileFromTheVaultKeepsItsName() {
        let id = UUID()
        let index: NoteFileSync.Index = [id: .init(fileName: "ideias.md", syncedText: "Projeto", followsTitle: false)]
        let file = NoteFileSync.File(name: "ideias.md", text: "Projeto", modified: past)
        let plan = NoteFileSync.plan(notes: [note("Projeto X", id: id, at: later)], files: [file], index: index)
        #expect(plan.renames.isEmpty)
        #expect(plan.writes == ["ideias.md": "Projeto X"])
    }

    @Test func bothEditedTheNewerWins() {
        let id = UUID()
        let index: NoteFileSync.Index = [id: .init(fileName: "A.md", syncedText: "A")]
        let file = NoteFileSync.File(name: "A.md", text: "A do Obsidian", modified: later)
        let older = NoteFileSync.plan(notes: [note("A daqui", id: id, at: past)], files: [file], index: index)
        #expect(older.updates == [id: "A do Obsidian"])
        let newer = NoteFileSync.plan(notes: [note("A daqui", id: id, at: Date(timeIntervalSince1970: 3_000))], files: [file], index: index)
        #expect(newer.writes == ["A daqui.md": "A daqui"] || newer.writes == ["A.md": "A daqui"])
        #expect(newer.updates.isEmpty)
    }

    @Test func deletingOnEitherSideDeletesOnTheOther() {
        let gone = UUID(), kept = UUID()
        let index: NoteFileSync.Index = [
            gone: .init(fileName: "Velha.md", syncedText: "Velha"),
            kept: .init(fileName: "Fica.md", syncedText: "Fica"),
        ]
        // "Velha" was deleted here; "Fica.md" was deleted in the vault.
        let files = [NoteFileSync.File(name: "Velha.md", text: "Velha", modified: past)]
        let plan = NoteFileSync.plan(notes: [note("Fica", id: kept)], files: files, index: index)
        #expect(plan.trash == ["Velha.md"])
        #expect(plan.deletes == [kept])
    }

    @Test func aFileEditedInTheVaultIsntTrashed() {
        let gone = UUID()
        let index: NoteFileSync.Index = [gone: .init(fileName: "Velha.md", syncedText: "Velha")]
        let files = [NoteFileSync.File(name: "Velha.md", text: "Velha, mas editada", modified: later)]
        let plan = NoteFileSync.plan(notes: [], files: files, index: index)
        #expect(plan.trash.isEmpty)
    }

    @Test func nothingChangedNothingToDo() {
        let id = UUID()
        let index: NoteFileSync.Index = [id: .init(fileName: "A.md", syncedText: "A")]
        let files = [NoteFileSync.File(name: "A.md", text: "A", modified: past)]
        let plan = NoteFileSync.plan(notes: [note("A", id: id)], files: files, index: index)
        #expect(plan.isEmpty)
        #expect(plan.index == index)
    }

    @Test func fileNamesLeaveOutWhatTheyCantHold() {
        #expect(NoteFileSync.fileName(for: note("# a/b: c?"), taken: []) == "a b c.md")
        #expect(NoteFileSync.fileName(for: note("- [ ]"), taken: []) == "Nota.md")
    }

    @Test func notesHTML() {
        let html = NoteHTML.render("# Mercado\n- pão\n- **leite**\n- [x] café\n\n`x` e *bem* e snake_case_name")
        #expect(html == "<h1>Mercado</h1><ul><li>pão</li><li><b>leite</b></li></ul><div>☑ café</div><div><br></div><div><tt>x</tt> e <i>bem</i> e snake_case_name</div>")
        #expect(NoteHTML.render("a < b & c") == "<div>a &lt; b &amp; c</div>")
    }

    @Test func obsidianVaultsNewestFirst() {
        let json = #"{"vaults":{"a":{"path":"/x/Antigo","ts":1000},"b":{"path":"/x/Novo","ts":2000,"open":true}}}"#
        #expect(ObsidianVaults.parse(Data(json.utf8)).map(\.name) == ["Novo", "Antigo"])
    }

    /// The whole round trip on a real folder: a note goes out, is edited in "Obsidian",
    /// comes back, is renamed by its new title here, and a new file there comes in.
    @Test func roundTripOnAFolder() throws {
        let sandbox = try Sandbox()
        let folder = sandbox.url("Cofre/Cleen")
        let id = UUID()
        var notes = [QuickNote(id: id, text: "Lis", updatedAt: past)]

        var plan = NoteFileSync.plan(notes: notes, files: try NoteFileSync.read(folder), index: [:])
        try NoteFileSync.perform(plan, in: folder)
        #expect(try String(contentsOf: folder.appending(path: "Lis.md"), encoding: .utf8) == "Lis")

        // Here: the title grows; the file follows.
        notes[0].text = "Lista do mercado"
        notes[0].updatedAt = later
        plan = NoteFileSync.plan(notes: notes, files: try NoteFileSync.read(folder), index: plan.index)
        try NoteFileSync.perform(plan, in: folder)
        #expect(try NoteFileSync.read(folder).map(\.name) == ["Lista do mercado.md"])

        // There: an edit, and a new file.
        try Data("Lista do mercado\n- café".utf8).write(to: folder.appending(path: "Lista do mercado.md"))
        try Data("Ideias".utf8).write(to: folder.appending(path: "ideias.md"))
        plan = NoteFileSync.plan(notes: notes, files: try NoteFileSync.read(folder), index: plan.index)
        try NoteFileSync.perform(plan, in: folder)
        #expect(plan.updates == [id: "Lista do mercado\n- café"])
        #expect(Array(plan.imports.values) == ["Ideias"])
        #expect(plan.writes.isEmpty)
    }
}
