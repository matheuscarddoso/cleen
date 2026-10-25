import AppKit
import CleenKit
import Foundation
import Observation

/// Keeps the quick notes in step with an Obsidian vault (both ways, as `.md` files in
/// its "Cleen" folder) or with the Notes app (Cleen to Notes: Notes only hands back plain
/// text, which would strip the Markdown here). Set in Ajustes › Notas.
@Observable
final class NotesSync {
    enum Target: String, CaseIterable, Identifiable {
        case none
        case obsidian
        case appleNotes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: String(localized: "Desligado")
            case .obsidian: "Obsidian"
            case .appleNotes: String(localized: "Notas")
            }
        }
    }

    enum Status: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
        /// Notes said no: Automação in Ajustes do Sistema has to allow it.
        case notAllowed
    }

    private(set) var target: Target
    /// The vault (not the Cleen folder inside it).
    private(set) var vault: URL?
    private(set) var status = Status.idle

    @ObservationIgnored private weak var notes: NotesModel?
    @ObservationIgnored private var poll: Task<Void, Never>?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var runAgain = false

    private static let targetKey = "notes.sync.target"
    private static let vaultKey = "notes.sync.vault"
    /// The vault's folder for Cleen's notes.
    static let folderName = "Cleen"
    private nonisolated static let indexFile = URL.applicationSupportDirectory.appending(path: "Cleen/notes-sync.json")

    init() {
        let defaults = UserDefaults.standard
        target = defaults.string(forKey: Self.targetKey).flatMap(Target.init(rawValue:)) ?? .none
        vault = defaults.string(forKey: Self.vaultKey).map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    /// The folder the notes go to in the vault.
    var folder: URL? { vault?.appending(path: Self.folderName, directoryHint: .isDirectory) }

    func start(notes: NotesModel) {
        self.notes = notes
        // Notes gets a breath after the last keystroke: each sync there is a script run.
        notes.onSaved = { [weak self] _ in
            guard let self else { return }
            self.schedule(after: self.target == .appleNotes ? .seconds(2) : .milliseconds(300))
        }
        restartPolling()
        schedule(after: .seconds(2))
    }

    func setTarget(_ target: Target) {
        guard target != self.target else { return }
        self.target = target
        UserDefaults.standard.set(target.rawValue, forKey: Self.targetKey)
        // A new target starts from a clean slate: nothing it knows was synced there yet.
        saveIndex(SyncIndex())
        status = .idle
        restartPolling()
        schedule(after: .zero)
    }

    func setVault(_ url: URL) {
        vault = url
        UserDefaults.standard.set(url.path(percentEncoded: false), forKey: Self.vaultKey)
        saveIndex(SyncIndex())
        status = .idle
        schedule(after: .zero)
    }

    func syncNow() { schedule(after: .zero) }

    /// Edits in the vault show up within a few seconds: its folder is checked every
    /// four while Obsidian is the target. Reading a handful of small files is cheap.
    private func restartPolling() {
        poll?.cancel()
        guard target == .obsidian else { return }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await self?.run()
            }
        }
    }

    private func schedule(after delay: Duration) {
        guard target != .none else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.run()
        }
    }

    /// One sync at a time; a request that comes in meanwhile runs right after.
    private func run() async {
        guard target != .none, let notes else { return }
        if isRunning {
            runAgain = true
            return
        }
        isRunning = true
        defer { isRunning = false }
        repeat {
            runAgain = false
            switch target {
            case .none: return
            case .obsidian: await syncObsidian(notes)
            case .appleNotes: await mirrorToAppleNotes(notes)
            }
        } while runAgain
    }

    // MARK: Obsidian

    private func syncObsidian(_ notes: NotesModel) async {
        guard let folder else {
            status = .failed(String(localized: "Escolha o cofre do Obsidian."))
            return
        }
        let index = loadIndex()
        let notebook = notes.current
        let outcome = await BlockingIO.run { () -> Result<NoteFileSync.Plan, ObsidianError> in
            Self.syncFiles(in: folder, notes: notebook.notes, index: index.obsidian)
        }
        switch outcome {
        case .success(let plan):
            var saved = index
            saved.obsidian = plan.index
            saveIndex(saved)
            // Typing since the sync began wins: only notes still as they were are
            // changed from the vault (the next sync then sends the typing there).
            let before = Dictionary(uniqueKeysWithValues: notebook.notes.map { ($0.id, $0.text) })
            let now = Dictionary(uniqueKeysWithValues: notes.current.notes.map { ($0.id, $0.text) })
            let untouched = { (id: UUID) in before[id] == now[id] }
            notes.apply(
                updates: plan.updates.filter { untouched($0.key) },
                imports: plan.imports,
                deletes: plan.deletes.filter(untouched)
            )
            status = .synced(.now)
        case .failure(let error):
            status = .failed(error.message)
        }
    }

    enum ObsidianError: Error {
        case missingVault
        case unwritable(String)

        var message: String {
            switch self {
            case .missingVault: String(localized: "O cofre do Obsidian não está mais lá.")
            case .unwritable(let detail): String(localized: "Não deu para gravar no cofre: \(detail)")
            }
        }
    }

    /// Reads the folder, plans, then does the file side of the plan. Blocking.
    private nonisolated static func syncFiles(in folder: URL, notes: [QuickNote], index: NoteFileSync.Index) -> Result<NoteFileSync.Plan, ObsidianError> {
        // A vault that went away (an unplugged drive, iCloud) must not read as "every
        // file was deleted": nothing happens until it's back.
        guard FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path(percentEncoded: false)) else { return .failure(.missingVault) }
        do {
            let plan = NoteFileSync.plan(notes: notes, files: try NoteFileSync.read(folder), index: index)
            try NoteFileSync.perform(plan, in: folder)
            return .success(plan)
        } catch {
            return .failure(.unwritable(error.localizedDescription))
        }
    }

    // MARK: Notes

    private func mirrorToAppleNotes(_ notes: NotesModel) async {
        var index = loadIndex()
        let current = notes.current.notes.filter { !$0.isBlank }
        let live = Set(current.map(\.id))
        status = .syncing
        for note in current where index.appleNotes[note.id]?.text != note.text {
            switch await AppleNotesBridge.upsert(id: index.appleNotes[note.id]?.noteID, html: NoteHTML.render(note.text)) {
            case .success(let noteID):
                index.appleNotes[note.id] = .init(noteID: noteID, text: note.text)
                saveIndex(index)
            case .failure(.notAllowed):
                status = .notAllowed
                return
            case .failure(.failed(let message)):
                status = .failed(message)
                return
            }
        }
        // Deleted here: deleted there (Notes keeps it in Apagadas Recentemente).
        for (id, entry) in index.appleNotes where !live.contains(id) {
            if case .failure(.notAllowed) = await AppleNotesBridge.delete(id: entry.noteID) {
                status = .notAllowed
                return
            }
            index.appleNotes[id] = nil
            saveIndex(index)
        }
        status = .synced(.now)
    }

    // MARK: Index

    /// What each side had at the last sync; see NoteFileSync.
    struct SyncIndex: Codable {
        struct AppleEntry: Codable {
            let noteID: String
            let text: String
        }

        var obsidian: NoteFileSync.Index = [:]
        var appleNotes: [UUID: AppleEntry] = [:]
    }

    private func loadIndex() -> SyncIndex {
        guard let data = try? Data(contentsOf: Self.indexFile) else { return SyncIndex() }
        return (try? JSONDecoder().decode(SyncIndex.self, from: data)) ?? SyncIndex()
    }

    private func saveIndex(_ index: SyncIndex) {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? FileManager.default.createDirectory(at: Self.indexFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.indexFile, options: .atomic)
    }
}
