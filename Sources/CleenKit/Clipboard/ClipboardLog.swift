import Foundation

/// The ordered history, newest first. Copying something already in it moves it to the
/// top and counts it instead of adding a duplicate.
public struct ClipboardLog: Codable, Sendable, Equatable {
    public private(set) var entries: [ClipboardEntry] = []
    public let limit: Int

    public init(limit: Int = 300) {
        self.limit = limit
    }

    /// Records a copy and returns entries that fell off the end (their image files can go).
    @discardableResult
    public mutating func record(_ entry: ClipboardEntry) -> [ClipboardEntry] {
        if let index = entries.firstIndex(where: { $0.contentHash == entry.contentHash && $0.kind == entry.kind }) {
            var existing = entries.remove(at: index)
            existing.lastCopied = entry.lastCopied
            existing.timesCopied += 1
            existing.sourceBundleID = entry.sourceBundleID ?? existing.sourceBundleID
            existing.sourceName = entry.sourceName ?? existing.sourceName
            entries.insert(existing, at: 0)
            // The new copy's own image file is a duplicate of the kept one.
            return entry.imageFile != nil && entry.imageFile != existing.imageFile ? [entry] : []
        }
        entries.insert(entry, at: 0)
        guard entries.count > limit else { return [] }
        // Drop the oldest unpinned copies.
        var dropped: [ClipboardEntry] = []
        while entries.count > limit, let index = entries.lastIndex(where: { !$0.pinned }) {
            dropped.append(entries.remove(at: index))
        }
        return dropped
    }

    /// Brings an entry back to the top, as when it's pasted from the history.
    public mutating func touch(_ id: UUID, at date: Date = .now) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.lastCopied = date
        entries.insert(entry, at: 0)
    }

    public mutating func togglePin(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isPinned = !entries[index].pinned
    }

    @discardableResult
    public mutating func remove(_ id: UUID) -> ClipboardEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    public mutating func removeAll() -> [ClipboardEntry] {
        defer { entries.removeAll() }
        return entries
    }
}
