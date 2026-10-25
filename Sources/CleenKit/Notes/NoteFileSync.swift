import Foundation

/// Two-way sync between the quick notes and a folder of Markdown files (a folder in an
/// Obsidian vault): one `.md` per note, named after its title.
///
/// The index remembers, per note, the file it went to and the text both sides had at
/// the last sync. That is what tells "edited here" from "edited there": a side whose
/// text still matches the index didn't change. When both changed, the newer edit wins.
/// `plan` only decides; the caller does the file work and saves the new index.
public enum NoteFileSync {
    public struct Entry: Codable, Sendable, Equatable {
        public var fileName: String
        public var syncedText: String
        /// Born in Cleen, so its file is renamed as the title takes shape. A file that
        /// came from the folder keeps its name: renaming it would break links to it.
        public var followsTitle: Bool

        public init(fileName: String, syncedText: String, followsTitle: Bool = true) {
            self.fileName = fileName
            self.syncedText = syncedText
            self.followsTitle = followsTitle
        }
    }

    public typealias Index = [UUID: Entry]

    /// A `.md` file in the folder, as read now.
    public struct File: Sendable, Equatable {
        public let name: String
        public let text: String
        public let modified: Date

        public init(name: String, text: String, modified: Date) {
            self.name = name
            self.text = text
            self.modified = modified
        }
    }

    public struct Plan: Sendable, Equatable {
        /// Files to write (created or changed), by name.
        public var writes: [String: String] = [:]
        /// A note's file whose name follows its new title: old name → new name.
        public var renames: [String: String] = [:]
        /// Files whose note was deleted here; they go to the Lixo.
        public var trash: [String] = []
        /// Notes edited in the folder: their new text.
        public var updates: [UUID: String] = [:]
        /// Files new to the folder: notes to add, with the id they get.
        public var imports: [UUID: String] = [:]
        /// Notes whose file was deleted in the folder.
        public var deletes: [UUID] = []
        public var index: Index = [:]

        public var isEmpty: Bool {
            writes.isEmpty && renames.isEmpty && trash.isEmpty && updates.isEmpty && imports.isEmpty && deletes.isEmpty
        }
    }

    public static func plan(notes: [QuickNote], files: [File], index: Index, makeID: () -> UUID = UUID.init) -> Plan {
        var plan = Plan()
        let filesByName = Dictionary(files.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var claimed = Set<String>()
        // Names in use once this sync is done, so a new or renamed file never lands on one.
        var taken = Set(files.map(\.name))

        for note in notes {
            guard let entry = index[note.id] else {
                guard !note.isBlank else { continue }
                let name = fileName(for: note, taken: taken)
                taken.insert(name)
                claimed.insert(name)
                plan.writes[name] = note.text
                plan.index[note.id] = Entry(fileName: name, syncedText: note.text)
                continue
            }
            claimed.insert(entry.fileName)
            let noteChanged = note.text != entry.syncedText
            guard let file = filesByName[entry.fileName] else {
                // Deleted in the folder. Unless it was edited here since, it goes here too.
                if noteChanged, !note.isBlank {
                    plan.writes[entry.fileName] = note.text
                    plan.index[note.id] = Entry(fileName: entry.fileName, syncedText: note.text, followsTitle: entry.followsTitle)
                } else {
                    plan.deletes.append(note.id)
                }
                continue
            }
            let fileChanged = file.text != entry.syncedText
            switch (noteChanged, fileChanged) {
            case (false, false):
                plan.index[note.id] = entry
            case (false, true):
                plan.updates[note.id] = file.text
                plan.index[note.id] = Entry(fileName: entry.fileName, syncedText: file.text, followsTitle: entry.followsTitle)
            case (true, true) where file.modified > note.updatedAt:
                plan.updates[note.id] = file.text
                plan.index[note.id] = Entry(fileName: entry.fileName, syncedText: file.text, followsTitle: entry.followsTitle)
            case (true, _):
                // Edited here (or both, and here is newer): the file follows, renamed if
                // the title moved.
                var name = entry.fileName
                if entry.followsTitle, stem(of: entry.fileName) != baseName(for: note) {
                    taken.remove(entry.fileName)
                    name = fileName(for: note, taken: taken)
                    taken.insert(name)
                    if name != entry.fileName { plan.renames[entry.fileName] = name }
                }
                claimed.insert(name)
                plan.writes[name] = note.text
                plan.index[note.id] = Entry(fileName: name, syncedText: note.text, followsTitle: entry.followsTitle)
            }
        }

        // Notes deleted here: their files go too, unless edited in the folder since.
        let live = Set(notes.map(\.id))
        for (id, entry) in index where !live.contains(id) {
            guard let file = filesByName[entry.fileName] else { continue }
            if file.text == entry.syncedText {
                plan.trash.append(entry.fileName)
            }
            claimed.insert(entry.fileName)
        }

        // Files nobody here knows: new notes.
        for file in files.sorted(by: { $0.name < $1.name }) where !claimed.contains(file.name) {
            guard !file.text.allSatisfy(\.isWhitespace) else { continue }
            let id = makeID()
            plan.imports[id] = file.text
            plan.index[id] = Entry(fileName: file.name, syncedText: file.text, followsTitle: false)
        }
        plan.trash.sort()
        return plan
    }

    /// The folder's `.md` files (created if it isn't there yet). Blocking.
    public static func read(_ folder: URL) throws -> [File] {
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let urls = try files.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        return urls.filter { $0.pathExtension.lowercased() == "md" }.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return File(name: url.lastPathComponent, text: text, modified: modified)
        }
    }

    /// The file side of a plan: renames first (so a write lands under the new name),
    /// then writes, then the files of notes deleted here go to the Lixo. Blocking.
    public static func perform(_ plan: Plan, in folder: URL) throws {
        let files = FileManager.default
        for (from, to) in plan.renames {
            try files.moveItem(at: folder.appending(path: from), to: folder.appending(path: to))
        }
        for (name, text) in plan.writes {
            try Data(text.utf8).write(to: folder.appending(path: name), options: .atomic)
        }
        for name in plan.trash {
            try? files.trashItem(at: folder.appending(path: name), resultingItemURL: nil)
        }
    }

    /// `Lista do mercado.md`, `Lista do mercado 2.md` when that's taken.
    public static func fileName(for note: QuickNote, taken: Set<String>) -> String {
        let base = baseName(for: note)
        var name = base + ".md"
        var number = 2
        while taken.contains(name) {
            name = "\(base) \(number).md"
            number += 1
        }
        return name
    }

    /// `Lista 2.md` → `Lista`: the name without its extension and the number added to
    /// tell it from a namesake.
    static func stem(of fileName: String) -> String {
        let bare = fileName.hasSuffix(".md") ? String(fileName.dropLast(3)) : fileName
        return bare.replacing(/\ \d+$/, with: "")
    }

    /// The title, without what file names can't hold, at most 80 characters.
    static func baseName(for note: QuickNote) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]").union(.newlines).union(.controlCharacters)
        let cleaned = (note.title ?? "")
            .unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let short = String(cleaned.prefix(80)).trimmingCharacters(in: .whitespaces)
        return short.isEmpty ? String(localized: "Nota") : short
    }
}
