import Foundation

/// Adds and removes Cleen's one entry in Claude Code's `settings.json`, leaving every
/// other key, hook and value where it was. Cleen's handler is recognised by its command
/// (the path to Cleen's hook script), so it can always be found and taken out again,
/// even after the person reformatted the file.
public enum ClaudeHookSettings {
    /// Fires when Claude Code is about to ask for permission, and only then.
    /// https://code.claude.com/docs/en/hooks#permissionrequest
    public static let event = "PermissionRequest"
    /// What identifies Cleen's handler in the command string.
    public static let marker = "/Cleen/hooks/claude-permission"
    /// Every tool except the two whose "permission" is really a question for the person
    /// (a multiple choice, a plan to read): those stay in the terminal. Claude Code
    /// matches it as a JavaScript regular expression.
    public static let matcher = "^(?!AskUserQuestion$|ExitPlanMode$)"
    /// Seconds Claude Code gives the hook before going on without it. The script and the
    /// app each give up a little earlier, so the answer is always "no decision" rather
    /// than a timed-out hook.
    public static let timeout = 120

    public enum Failure: Error, Equatable, Sendable {
        /// Not valid JSON: refused, so nothing of the person's is lost.
        case malformed(line: Int)
        /// Valid JSON in a shape Claude Code wouldn't accept either (`hooks` as a list…).
        case unexpectedShape(path: String)
    }

    /// The command Claude Code runs: the script's path, quoted for `sh -c` because
    /// `Application Support` has a space in it.
    public static func command(for script: URL) -> String {
        shellQuoted(script.path(percentEncoded: false))
    }

    public static func shellQuoted(_ text: String) -> String {
        "'" + text.replacing("'", with: #"'\''"#) + "'"
    }

    /// Whether the text has Cleen's handler under `PermissionRequest`.
    public static func isInstalled(in text: String) -> Bool {
        guard let root = try? JSONValue.parse(text), let groups = root["hooks"]?[event]?.arrayValue else { return false }
        return groups.contains { group in group["hooks"]?.arrayValue?.contains(where: isCleen) == true }
    }

    /// The file with Cleen's handler in it. Installing twice replaces the first entry
    /// in place instead of adding another.
    public static func installing(into text: String?, command: String) throws(Failure) -> String {
        let source = text ?? ""
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return JSONValue.object([JSONMember("hooks", .object([JSONMember(event, .array([group(command: command)]))]))]).printed()
        }
        guard case .object(var root) = try parse(source) else { throw .unexpectedShape(path: "/") }

        var hooks: [JSONMember]
        switch root.first(where: { $0.key == "hooks" })?.value {
        case nil, .null?: hooks = []
        case .object(let members)?: hooks = members
        default: throw .unexpectedShape(path: "hooks")
        }

        var groups: [JSONValue]
        switch hooks.first(where: { $0.key == event })?.value {
        case nil, .null?: groups = []
        case .array(let values)?: groups = values
        default: throw .unexpectedShape(path: "hooks.\(event)")
        }

        // An older Cleen entry goes, and the new one takes its place in the list.
        let position = groups.firstIndex { $0["hooks"]?.arrayValue?.contains(where: isCleen) == true }
        groups = groups.compactMap(withoutCleen)
        groups.insert(group(command: command), at: min(position ?? groups.count, groups.count))

        hooks.set(event, .array(groups))
        root.set("hooks", .object(hooks))
        return JSONValue.object(root).printed(.detect(in: source))
    }

    /// The file without Cleen's handler, anywhere it appears. Groups, events and the
    /// `hooks` key that only held Cleen's go too. Returns the text untouched when there
    /// was nothing of Cleen's in it.
    public static func removing(from text: String) throws(Failure) -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        guard case .object(var root) = try parse(text) else { throw .unexpectedShape(path: "/") }
        guard case .object(var hooks)? = root.first(where: { $0.key == "hooks" })?.value else { return text }

        var changed = false
        for member in hooks {
            guard case .array(let groups) = member.value else { continue }
            let kept = groups.compactMap(withoutCleen)
            guard kept != groups else { continue }
            changed = true
            if kept.isEmpty { hooks.remove(member.key) } else { hooks.set(member.key, .array(kept)) }
        }
        guard changed else { return text }
        if hooks.isEmpty { root.remove("hooks") } else { root.set("hooks", .object(hooks)) }
        return JSONValue.object(root).printed(.detect(in: text))
    }

    // MARK: Pieces

    private static func group(command: String) -> JSONValue {
        .object([
            JSONMember("matcher", .string(matcher)),
            JSONMember("hooks", .array([
                .object([
                    JSONMember("type", .string("command")),
                    JSONMember("command", .string(command)),
                    JSONMember("timeout", .number(String(timeout))),
                ]),
            ])),
        ])
    }

    private static func isCleen(_ handler: JSONValue) -> Bool {
        handler["command"]?.stringValue?.contains(marker) == true
    }

    /// The group without Cleen's handlers; `nil` when nothing else was in it.
    private static func withoutCleen(_ group: JSONValue) -> JSONValue? {
        guard case .object(var members) = group, case .array(let handlers)? = group["hooks"] else { return group }
        let kept = handlers.filter { !isCleen($0) }
        guard kept.count != handlers.count else { return group }
        if kept.isEmpty { return nil }
        members.set("hooks", .array(kept))
        return .object(members)
    }

    private static func parse(_ text: String) throws(Failure) -> JSONValue {
        do {
            return try JSONValue.parse(text)
        } catch {
            throw .malformed(line: error.line)
        }
    }
}
