import Foundation

/// How a run ended.
public enum ShortcutRunOutcome: Sendable, Equatable {
    case succeeded
    /// A one-line, human-sized reason, from the CLI's stderr.
    case failed(String)
    /// The run was stopped (task cancelled, process terminated).
    case stopped
}

/// The `shortcuts` command-line tool that ships with macOS: the only public way to list
/// and run the person's shortcuts from another app.
public enum ShortcutsCLI {
    public static let path = "/usr/bin/shortcuts"

    /// Lists the library and its folders. Folder membership needs one extra listing per
    /// folder; the CLI answers each in milliseconds, so they run side by side.
    public static func library() async throws -> ShortcutLibrary {
        let all = try await list([])
        let shortcuts = parseList(all)
        let folders = parseList((try? await list(["--folders"])) ?? "")
        let filled = await withTaskGroup(of: (Int, Set<String>).self) { group in
            for (index, folder) in folders.enumerated() {
                group.addTask {
                    let members = (try? await list(["--folder-name", folder.id])).map(parseList) ?? []
                    return (index, Set(members.map(\.id)))
                }
            }
            var members = [Int: Set<String>]()
            for await (index, ids) in group { members[index] = ids }
            return folders.enumerated().map { index, folder in
                ShortcutFolder(id: folder.id, name: folder.name, memberIDs: members[index] ?? [])
            }
        }
        return ShortcutLibrary(shortcuts: shortcuts, folders: filled.filter { !$0.memberIDs.isEmpty })
    }

    /// Runs a shortcut by its identifier (or name). Cancelling the calling task
    /// terminates the run.
    public static func run(_ id: String) async -> ShortcutRunOutcome {
        do {
            let result = try await Shell.run(path, ["run", id])
            if Task.isCancelled { return .stopped }
            if result.succeeded { return .succeeded }
            // SIGTERM from our own cancellation, or the person quitting the run.
            if result.status == 15 { return .stopped }
            return .failed(failureSummary(stderr: result.stderr, status: result.status))
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// The URL that opens a shortcut in the Shortcuts editor.
    public static func openURL(name: String) -> URL {
        // Strict unreserved set: `&`, `+`, `=` and `#` in a name must not leak into the
        // query's syntax, which `URLComponents.queryItems` would allow.
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encoded = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return URL(string: "shortcuts://open-shortcut?name=\(encoded)") ?? appURL
    }

    /// Opens the Shortcuts app on its library.
    public static let appURL = URL(string: "shortcuts://")!

    // MARK: Parsing

    /// Parses `shortcuts list` output, one shortcut per line, with or without
    /// `--show-identifiers` (`Name (UUID)`). Names may contain parentheses themselves;
    /// only a trailing UUID in parentheses counts as the identifier.
    public static func parseList(_ output: String) -> [ShortcutEntry] {
        output.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            if line.hasSuffix(")"), let open = line.range(of: " (", options: .backwards) {
                let candidate = line[open.upperBound..<line.index(before: line.endIndex)]
                if UUID(uuidString: String(candidate)) != nil {
                    let name = line[..<open.lowerBound].trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { return ShortcutEntry(id: String(candidate), name: name) }
                }
            }
            return ShortcutEntry(id: line, name: line)
        }
    }

    /// Boils the CLI's stderr down to one readable line: no `Error:` prefix, no trailing
    /// `(SomeErrorDomain error 1.)` code when there's a real message before it.
    public static func failureSummary(stderr: String, status: Int32) -> String {
        let lines = stderr.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard var line = lines.first else { return "Terminou com código \(status)." }
        for prefix in ["Error:", "error:", "Erro:"] where line.hasPrefix(prefix) {
            line = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        }
        if let range = line.range(of: #"\s*\([^()]*(error|erro) -?\d+\.?\)\.?$"#, options: [.regularExpression, .caseInsensitive]) {
            let message = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            if !message.isEmpty { line = message }
        }
        if line.isEmpty { return "Terminou com código \(status)." }
        return line.count > 140 ? String(line.prefix(139)) + "…" : line
    }

    private static func list(_ arguments: [String]) async throws -> String {
        let result = try await Shell.run(path, ["list", "--show-identifiers"] + arguments)
        guard result.succeeded else { throw ShellError.failed(result) }
        return result.stdout
    }
}
