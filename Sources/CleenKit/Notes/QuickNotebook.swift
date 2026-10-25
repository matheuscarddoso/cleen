import Foundation

/// The handful of quick notes and which one is open. There's always at least one note,
/// so the editor never has nothing to show, and a note left blank doesn't keep a chip.
public struct QuickNotebook: Codable, Sendable, Equatable {
    /// Quick notes, not an archive: past a few they stop being quick to find. It only
    /// stops new notes; text already written is never dropped to honor it.
    public static let limit = 8

    public private(set) var notes: [QuickNote]
    public private(set) var selectedID: UUID

    public init(notes: [QuickNote] = [], selectedID: UUID? = nil) {
        self.notes = notes.isEmpty ? [QuickNote()] : notes
        self.selectedID = selectedID.flatMap { id in notes.first { $0.id == id }?.id } ?? self.notes[0].id
    }

    private enum CodingKeys: String, CodingKey {
        case notes
        case selectedID
    }

    /// A file edited by hand (or by an older build) still loads into a valid notebook.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let notes = try container.decodeIfPresent([QuickNote].self, forKey: .notes) ?? []
        let selected = try container.decodeIfPresent(UUID.self, forKey: .selectedID)
        self.init(notes: notes, selectedID: selected)
    }

    public var selected: QuickNote {
        notes.first { $0.id == selectedID } ?? notes[0]
    }

    public var canAdd: Bool { notes.count < Self.limit }

    /// Opens another note. The one being left goes away if it was left blank.
    public mutating func select(_ id: UUID) {
        guard id != selectedID, notes.contains(where: { $0.id == id }) else { return }
        let previous = selectedID
        selectedID = id
        if let index = notes.firstIndex(where: { $0.id == previous }), notes[index].isBlank {
            notes.remove(at: index)
        }
    }

    /// Starts a note, or goes back to the blank one already waiting. False at the limit.
    @discardableResult
    public mutating func add(at date: Date = .now) -> Bool {
        if let blank = notes.first(where: \.isBlank) {
            select(blank.id)
            return true
        }
        guard canAdd else { return false }
        let note = QuickNote(updatedAt: date)
        notes.append(note)
        select(note.id)
        return true
    }

    public mutating func update(_ id: UUID, text: String, at date: Date = .now) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].text != text else { return }
        notes[index].text = text
        notes[index].updatedAt = date
    }

    /// Removes a note and opens the one that took its place. The last note is emptied
    /// instead, so there's always somewhere to write.
    public mutating func remove(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes.remove(at: index)
        if notes.isEmpty { notes = [QuickNote()] }
        if selectedID == id || !notes.contains(where: { $0.id == selectedID }) {
            selectedID = notes[min(index, notes.count - 1)].id
        }
    }

    /// A note that arrived from outside (a file in the synced vault). Past the limit too:
    /// text already written is never dropped.
    public mutating func insert(_ note: QuickNote) {
        guard !notes.contains(where: { $0.id == note.id }) else { return }
        // A blank note waiting to be written in makes room instead of staying behind.
        if notes.count == 1, notes[0].isBlank {
            notes = [note]
            selectedID = note.id
        } else {
            notes.append(note)
        }
    }

    /// Folds in notes written while this notebook was still loading from disk: they're
    /// kept and the one being written stays open.
    public mutating func absorb(_ written: QuickNotebook) {
        let known = Set(notes.map(\.id))
        let fresh = written.notes.filter { !$0.isBlank && !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        notes = notes.filter { !$0.isBlank } + fresh
        let open = written.selected
        selectedID = notes.contains { $0.id == open.id } ? open.id : notes[notes.count - 1].id
    }
}
