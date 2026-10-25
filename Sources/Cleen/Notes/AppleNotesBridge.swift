import CleenKit
import Foundation

/// The Notes app, driven with AppleScript: a "Cleen" folder holds one note per quick
/// note. The note's text goes in as an argument to the script, never pasted into it,
/// so nothing written in a note can become a command.
enum AppleNotesBridge {
    enum Failure: Error, Equatable {
        /// Ajustes do Sistema › Privacidade e Segurança › Automação turned it down.
        case notAllowed
        case failed(String)
    }

    static let folderName = "Cleen"

    /// Creates the note, or replaces the body of the one with `id` (when it's still
    /// there). Answers the note's id in Notes.
    static func upsert(id: String?, html: String) async -> Result<String, Failure> {
        let script = """
        on run argv
            set noteID to item 1 of argv
            set noteBody to item 2 of argv
            tell application "Notes"
                if not (exists folder "\(folderName)") then make new folder with properties {name:"\(folderName)"}
                if noteID is not "" then
                    try
                        set existing to note id noteID
                        set body of existing to noteBody
                        return id of existing
                    end try
                end if
                set created to make new note at folder "\(folderName)" with properties {body:noteBody}
                return id of created
            end tell
        end run
        """
        return await run(script, [id ?? "", html]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Deletes the note (Notes keeps it in Apagadas Recentemente for a while).
    static func delete(id: String) async -> Result<Void, Failure> {
        let script = """
        on run argv
            tell application "Notes"
                try
                    delete note id (item 1 of argv)
                end try
            end tell
        end run
        """
        return await run(script, [id]).map { _ in () }
    }

    private static func run(_ script: String, _ arguments: [String]) async -> Result<String, Failure> {
        guard let result = try? await Shell.run("/usr/bin/osascript", ["-e", script] + arguments, timeout: .seconds(30)) else {
            return .failure(.failed(String(localized: "O app Notas não respondeu.")))
        }
        guard result.succeeded else {
            // -1743: the person (or a past "Don't Allow") said no to controlling Notes.
            if result.stderr.contains("-1743") { return .failure(.notAllowed) }
            return .failure(.failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return .success(result.stdout)
    }
}
