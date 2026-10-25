import AppKit
import CleenKit
import Foundation
import Observation

/// The quick notes, saved as the person types: a short pause after the last keystroke
/// writes them to Application Support, off the main thread.
@Observable
final class NotesModel {
    private(set) var notebook = QuickNotebook()

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var editedBeforeLoad = false
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?
    /// Told after each save, with what was saved: the sync follows from there.
    @ObservationIgnored var onSaved: (QuickNotebook) -> Void = { _ in }

    private nonisolated static let folder = URL.applicationSupportDirectory.appending(path: "Cleen", directoryHint: .isDirectory)
    private nonisolated static let file = folder.appending(path: "notes.json")
    /// One write at a time, in order: a slow older write can't land over a newer one.
    private nonisolated static let writer = DispatchQueue(label: "app.cleen.notes-writer", qos: .utility)
    /// Long enough to batch a burst of typing, short enough that nothing typed is lost
    /// to a quit.
    private static let saveDelay = Duration.milliseconds(600)

    init() {
        Task { await load() }
        // A save still waiting when Cleen quits is written right away.
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    var selected: QuickNote { notebook.selected }
    var canAdd: Bool { notebook.canAdd }

    /// The open note's text, for the editor.
    var text: String {
        get { notebook.selected.text }
        set {
            guard newValue != notebook.selected.text else { return }
            notebook.update(notebook.selectedID, text: newValue)
            changed()
        }
    }

    func select(_ note: QuickNote) {
        notebook.select(note.id)
        changed()
    }

    @discardableResult
    func add() -> Bool {
        let added = notebook.add()
        if added { changed() }
        return added
    }

    func delete(_ note: QuickNote) {
        notebook.remove(note.id)
        changed()
    }

    /// What the synced vault changed: notes edited there, new ones, deleted ones.
    func apply(updates: [UUID: String], imports: [UUID: String], deletes: [UUID]) {
        guard !updates.isEmpty || !imports.isEmpty || !deletes.isEmpty else { return }
        for (id, text) in updates { notebook.update(id, text: text) }
        for (id, text) in imports.sorted(by: { $0.value < $1.value }) { notebook.insert(QuickNote(id: id, text: text)) }
        for id in deletes { notebook.remove(id) }
        changed()
    }

    /// The notes as they are now, for a sync that didn't start from a save.
    var current: QuickNotebook { notebook }

    func copy(_ note: QuickNote) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(note.text, forType: .string)
    }

    // MARK: Saving

    private func changed() {
        if !isLoaded { editedBeforeLoad = true }
        scheduleSave()
    }

    private func load() async {
        let file = Self.file
        let saved = await offMain { () -> QuickNotebook? in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(QuickNotebook.self, from: data)
        }
        isLoaded = true
        guard var saved else { return }
        // Typing that beat the read joins what was on disk instead of replacing it.
        if editedBeforeLoad {
            saved.absorb(notebook)
            notebook = saved
            scheduleSave()
        } else {
            notebook = saved
        }
    }

    private func scheduleSave() {
        // Never write before the file was read: that would replace it with a blank note.
        guard isLoaded else { return }
        saveTask?.cancel()
        let notebook = notebook
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Self.writer.async { @Sendable in
                    Self.write(notebook)
                    continuation.resume()
                }
            }
            if !Task.isCancelled { self.saveTask = nil }
            self.onSaved(notebook)
        }
    }

    private func flush() {
        guard let saveTask else { return }
        saveTask.cancel()
        self.saveTask = nil
        let notebook = notebook
        // Behind any write already under way; a small file, so quitting barely waits.
        Self.writer.sync { Self.write(notebook) }
    }

    private nonisolated static func write(_ notebook: QuickNotebook) {
        guard let data = try? JSONEncoder().encode(notebook) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }
}
