import Foundation

/// Puts Cleen's permission hook into Claude Code and takes it out again. Opt-in, and
/// built so it can't break Claude Code: a file it can't read is refused, the original is
/// copied aside first, the write is atomic, and a symlinked `settings.json` (dotfiles)
/// is written through, not replaced.
public struct ClaudeHookInstaller: Sendable {
    public enum Status: Sendable, Equatable {
        case notInstalled
        case installed
        /// The entry is in `settings.json` but the script is gone: installing again fixes it.
        case incomplete
        /// No `~/.claude` folder: Claude Code never ran here.
        case claudeCodeMissing
        case unreadable(Failure)
    }

    public enum Failure: Error, Sendable, Equatable {
        case claudeCodeMissing
        case malformed(line: Int)
        case unexpectedShape(path: String)
        /// Claude Code (or the person) changed the file while Cleen was editing it.
        case changedWhileEditing
        case io(String)
    }

    /// `~/.claude/settings.json`.
    public let settings: URL
    /// `~/Library/Application Support/Cleen/hooks/claude-permission`.
    public let script: URL
    /// The socket the script talks to.
    public let socket: URL

    public init(settings: URL, script: URL, socket: URL) {
        self.settings = settings
        self.script = script
        self.socket = socket
    }

    public static let standard: ClaudeHookInstaller = {
        let support = URL.applicationSupportDirectory.appending(path: "Cleen", directoryHint: .isDirectory)
        return ClaudeHookInstaller(
            settings: Paths.home.appending(path: ".claude/settings.json"),
            script: support.appending(path: "hooks/claude-permission"),
            socket: support.appending(path: "agent.sock")
        )
    }()

    public var backup: URL { settings.deletingLastPathComponent().appending(path: settings.lastPathComponent + ".cleen-backup") }

    private var command: String { ClaudeHookSettings.command(for: script) }

    // MARK: Status

    public func status() -> Status {
        guard exists(settings.deletingLastPathComponent()) else { return .claudeCodeMissing }
        let text: String
        do {
            guard let read = try readSettings() else { return .notInstalled }
            text = read
            _ = try Self.checked { () throws(ClaudeHookSettings.Failure) in try ClaudeHookSettings.removing(from: text) }
        } catch {
            return .unreadable(error)
        }
        guard ClaudeHookSettings.isInstalled(in: text) else { return .notInstalled }
        return FileManager.default.isExecutableFile(atPath: script.path(percentEncoded: false)) ? .installed : .incomplete
    }

    // MARK: Install and remove

    public func install() throws(Failure) {
        guard exists(settings.deletingLastPathComponent()) else { throw .claudeCodeMissing }
        // Refuse before touching anything: a file that doesn't parse stays as it is.
        let original = try readSettings()
        let updated = try Self.checked { () throws(ClaudeHookSettings.Failure) in
            try ClaudeHookSettings.installing(into: original, command: command)
        }
        try writeScript()
        try replaceSettings(original: original, with: updated)
    }

    public func uninstall() throws(Failure) {
        if let original = try readSettings() {
            let updated = try Self.checked { () throws(ClaudeHookSettings.Failure) in try ClaudeHookSettings.removing(from: original) }
            if updated != original { try replaceSettings(original: original, with: updated) }
        }
        try? FileManager.default.removeItem(at: script)
        let folder = script.deletingLastPathComponent()
        if (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))?.isEmpty == true {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // MARK: The script

    /// The hook itself. When Cleen isn't running (no socket) it exits at once, without
    /// spawning anything, so Claude Code asks in the terminal as usual. When Cleen is
    /// running it hands the request over and prints Cleen's answer, or nothing at all
    /// if the person dismissed it or didn't answer in time; either way the terminal
    /// prompt takes over. It always exits 0: for this event a failing hook never
    /// decides anything, but it would still print an error in the session.
    public var scriptContents: String {
        let socketPath = ClaudeHookSettings.shellQuoted(socket.path(percentEncoded: false))
        return """
        #!/bin/sh
        # Cleen: Claude Code permission requests, answered from the notch.
        # Installed and removed in Cleen > Ajustes > Claude Code.
        socket=\(socketPath)
        [ -S "$socket" ] || exit 0
        /usr/bin/curl --silent --fail --max-time \(ClaudeHookSettings.timeout - 5) \\
          --unix-socket "$socket" -H 'Content-Type: application/json' -H 'Expect:' \\
          --data-binary @- http://cleen/claude/permission 2>/dev/null
        exit 0

        """
    }

    private func writeScript() throws(Failure) {
        do {
            try FileManager.default.createDirectory(at: script.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(scriptContents.utf8).write(to: script, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path(percentEncoded: false))
        } catch {
            throw .io(error.localizedDescription)
        }
    }

    // MARK: settings.json

    /// The real file behind a symlinked `settings.json`.
    private var resolvedSettings: URL { settings.resolvingSymlinksInPath() }

    /// `nil` when there's no file yet. Text that isn't UTF-8 is refused like bad JSON:
    /// decoding it leniently would write replacement characters back.
    private func readSettings() throws(Failure) -> String? {
        let url = resolvedSettings
        guard exists(url) else { return nil }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw .io(error.localizedDescription) }
        guard let text = String(validating: data, as: UTF8.self) else { throw .malformed(line: 1) }
        return text
    }

    private func replaceSettings(original: String?, with updated: String) throws(Failure) {
        let target = resolvedSettings
        let path = target.path(percentEncoded: false)
        let permissions = (try? FileManager.default.attributesOfItem(atPath: path))?[.posixPermissions] as? Int
        do {
            if let original { try Data(original.utf8).write(to: backup, options: .atomic) }
        } catch {
            throw .io(error.localizedDescription)
        }
        // Claude Code writes this file too. Only replace what was read.
        guard (try? readSettings()) == original else { throw .changedWhileEditing }
        do {
            try Data(updated.utf8).write(to: target, options: .atomic)
            if let permissions { try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: path) }
        } catch {
            throw .io(error.localizedDescription)
        }
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    private static func checked<T>(_ work: () throws(ClaudeHookSettings.Failure) -> T) throws(Failure) -> T {
        do {
            return try work()
        } catch {
            switch error {
            case .malformed(let line): throw .malformed(line: line)
            case .unexpectedShape(let path): throw .unexpectedShape(path: path)
            }
        }
    }
}
