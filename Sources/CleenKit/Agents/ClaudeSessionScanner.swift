import Foundation

/// Finds the Claude Code sessions that moved recently and reads their state.
public struct ClaudeSessionScanner: Sendable {
    /// Where the transcripts are looked for, each a Claude Code `projects` folder.
    public enum Roots: Sendable {
        /// Every config folder found at each scan (see `projectFolders`), so one set up
        /// while the app runs is picked up.
        case discovered(home: URL, configDir: String?)
        case fixed([URL])
    }

    public let roots: Roots
    /// Sessions untouched for longer than this aren't shown.
    public let window: TimeInterval

    public init(roots: Roots = .discovered(home: Paths.home, configDir: ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]), window: TimeInterval = 30 * 60) {
        self.roots = roots
        self.window = window
    }

    public init(root: URL, window: TimeInterval = 30 * 60) {
        self.init(roots: .fixed([root]), window: window)
    }

    /// A background agent or workflow whose files haven't moved for this long is taken
    /// as gone, even if nothing got to say it finished.
    public static let agentActivity: TimeInterval = 10 * 60

    /// The `projects` folders of every Claude Code config on this Mac: `~/.claude`, the
    /// side-by-side ones people make for a second account (`~/.claude-work`), and
    /// `$CLAUDE_CONFIG_DIR`. Only folders that exist; a directory listing, nothing read.
    public static func projectFolders(home: URL, configDir: String?) -> [URL] {
        var configs = [home.appending(path: ".claude", directoryHint: .isDirectory)]
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: home.path(percentEncoded: false))) ?? []
        configs += entries.filter { $0.hasPrefix(".claude-") }.sorted().map { home.appending(path: $0, directoryHint: .isDirectory) }
        if let configDir, !configDir.isEmpty {
            configs.append(URL(filePath: (configDir as NSString).expandingTildeInPath, directoryHint: .isDirectory))
        }
        var seen = Set<String>()
        return configs
            .map { $0.appending(path: "projects", directoryHint: .isDirectory).standardizedFileURL.resolvingSymlinksInPath() }
            .filter { folder in
                var isFolder: ObjCBool = false
                let path = folder.path(percentEncoded: false)
                return FileManager.default.fileExists(atPath: path, isDirectory: &isFolder) && isFolder.boolValue && seen.insert(path).inserted
            }
    }

    var projectFolders: [URL] {
        switch roots {
        case .discovered(let home, let configDir): Self.projectFolders(home: home, configDir: configDir)
        case .fixed(let folders): folders
        }
    }

    /// Newest first. Reads only transcripts modified inside the window (or whose
    /// background work is still going); blocking, so call it off the main thread.
    public func scan(now: Date = .now) -> [ClaudeSession] {
        var newest: [String: ClaudeSession] = [:]
        for root in projectFolders {
            // The same session can show up under two configs (a copied folder, a symlink):
            // the one that moved last is the live one.
            for session in scan(root, now: now) where (newest[session.id]?.updatedAt ?? .distantPast) < session.updatedAt {
                newest[session.id] = session
            }
        }
        return newest.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func scan(_ root: URL, now: Date) -> [ClaudeSession] {
        let files = FileManager.default
        guard let projects = try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        var sessions: [ClaudeSession] = []
        for project in projects {
            // A folder's date moves when a transcript is created in it, not appended to,
            // so every folder is listed; listing is cheap next to reading.
            guard let transcripts = try? files.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
            for file in transcripts where file.pathExtension == "jsonl" {
                guard let modified = Self.modificationDate(of: file),
                      // A workflow can run for hours while its session's own file sits still.
                      now.timeIntervalSince(modified) <= max(window, 24 * 3600)
                else { continue }
                let id = file.deletingPathExtension().lastPathComponent
                let folder = project.appending(path: id, directoryHint: .isDirectory)
                // Most sessions never start background work: one stat, not two listings.
                let work = files.fileExists(atPath: folder.path(percentEncoded: false)) ? Self.backgroundWork(in: folder, now: now) : BackgroundWork()
                let updated = max(modified, work.latest ?? .distantPast)
                guard now.timeIntervalSince(updated) <= window,
                      let tail = Self.tail(of: file, bytes: ClaudeSessionParser.tailBytes),
                      let session = ClaudeSessionParser.session(id: id, tail: tail, updatedAt: updated)
                else { continue }
                sessions.append(work.isGoing ? session.delegating(agents: work.agents, workflows: work.workflows) : session)
            }
        }
        return sessions
    }

    /// What's still at work for a session in the background, from its folder next to the
    /// transcript. `latest` is when any of it last wrote, done or not.
    struct BackgroundWork: Equatable {
        var agents = 0
        var workflows = 0
        var latest: Date?

        var isGoing: Bool { agents > 0 || workflows > 0 }
    }

    /// Plain background subagents write `subagents/agent-<id>.jsonl`. A dynamic workflow
    /// writes its agents to `subagents/workflows/<runId>/` (with a `journal.jsonl` of its
    /// own) and, only once it ends, a snapshot to `workflows/<runId>.json`.
    static func backgroundWork(in sessionFolder: URL, now: Date) -> BackgroundWork {
        let subagents = sessionFolder.appending(path: "subagents")
        let plain = activeAgents(in: subagents, now: now)
        var work = BackgroundWork(agents: plain.count, latest: plain.latest)
        let runs = (try? FileManager.default.contentsOfDirectory(at: subagents.appending(path: "workflows"), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        for run in runs where (try? run.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            let snapshot = sessionFolder.appending(path: "workflows").appending(path: run.lastPathComponent + ".json")
            let state = workflowRun(run, snapshot: snapshot, now: now)
            if let latest = state.latest { work.latest = max(work.latest ?? latest, latest) }
            if state.isGoing {
                work.workflows += 1
                work.agents += state.agents
            }
        }
        return work
    }

    /// One workflow run: going while nothing says it ended and its folder moved within
    /// `agentActivity`, with at least one agent while it goes (between phases none may be
    /// mid-turn, but the run is).
    static func workflowRun(_ folder: URL, snapshot: URL, now: Date) -> (isGoing: Bool, agents: Int, latest: Date?) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let latest = files.compactMap { modificationDate(of: $0) }.max()
        // The dates first: every past run of every session from the last day is listed
        // on each scan, and only one that moved lately is worth opening files for.
        guard let latest, now.timeIntervalSince(latest) <= agentActivity,
              !isTerminal(snapshot: snapshot)
        else { return (false, 0, latest) }
        let journal = WorkflowJournal.read(folder.appending(path: "journal.jsonl"))
        guard !journal.ended else { return (false, 0, latest) }
        let agents = activeAgents(in: folder, now: now, finished: journal.finishedAgents).count
        return (true, max(1, agents), latest)
    }

    /// The agents still working in a folder: each writes `agent-<id>.jsonl` next to an
    /// `agent-<id>.meta.json`. `latest` is when any of them last wrote, finished or not.
    /// `finished` holds the ids something else already says are done (a workflow's journal).
    static func activeAgents(in folder: URL, now: Date, finished: Set<String> = []) -> (count: Int, latest: Date?) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return (0, nil) }
        var count = 0
        var latest: Date?
        // Only agents: a workflow's journal.jsonl sits beside them and never ends a turn.
        for file in files where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("agent-") {
            guard let modified = modificationDate(of: file) else { continue }
            latest = max(latest ?? modified, modified)
            guard now.timeIntervalSince(modified) <= agentActivity,
                  !finished.contains(String(file.deletingPathExtension().lastPathComponent.dropFirst("agent-".count)))
            else { continue }
            // Current Claude Code never writes `finished`: then the agent's own last word says it.
            let meta = file.deletingPathExtension().appendingPathExtension("meta.json")
            if !isFinished(meta), !endedItsTurn(file) { count += 1 }
        }
        return (count, latest)
    }

    /// Statuses a workflow snapshot ends on. Anything else is left to the activity rule,
    /// so a status this doesn't know can't hide a run that's still going for long.
    static let terminalStatuses: Set<String> = ["completed", "failed", "killed", "cancelled", "canceled", "stopped", "error", "timeout", "timed_out"]

    /// The run's snapshot says it's over. Claude Code writes it as the run ends; with no
    /// `status`, an `error` means it failed and its absence that it completed.
    static func isTerminal(snapshot: URL) -> Bool {
        guard let data = try? Data(contentsOf: snapshot),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        guard let status = object["status"] as? String else { return true }
        return terminalStatuses.contains(status.lowercased())
    }

    /// What a run's `journal.jsonl` says: which agents handed in a `result`, and whether
    /// its last event closes the whole run.
    struct WorkflowJournal: Equatable {
        var ended = false
        var finishedAgents: Set<String> = []

        /// Results carry the agent's whole report, so the journal grows with the run;
        /// past this, older agents are left to their own transcripts.
        static let readBytes = 1024 * 1024

        static func read(_ journal: URL) -> WorkflowJournal {
            guard let tail = ClaudeSessionScanner.tail(of: journal, bytes: readBytes) else { return WorkflowJournal() }
            let events = tail.split(separator: UInt8(ascii: "\n")).compactMap { try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any] }
            var journal = WorkflowJournal()
            for event in events where event["type"] as? String == "result" {
                if let agent = event["agentId"] as? String { journal.finishedAgents.insert(agent) }
            }
            // Per-agent events carry the agent's id, so only one without it speaks for
            // the whole run.
            if let last = events.last, last["agentId"] == nil, let type = last["type"] as? String {
                journal.ended = ["completed", "failed", "killed", "cancelled", "canceled", "finished"].contains(type)
            }
            return journal
        }
    }

    /// Tools an agent hands its report back with, as its last act: plain background
    /// agents call SubagentHandback, workflow agents StructuredOutput. Their result is the
    /// last line such an agent writes, and it's done, not waiting for the model.
    static let handbackTools: Set<String> = ["SubagentHandback", "StructuredOutput"]

    static func endedItsTurn(_ transcript: URL) -> Bool {
        // A handback's call carries the agent's whole report (often past 64 KB), so it
        // can sit further back than the usual tail: only then is more read.
        for bytes in [64 * 1024, 1024 * 1024] {
            guard let tail = tail(of: transcript, bytes: bytes) else { return false }
            if let ended = lastWord(in: tail) { return ended }
        }
        return false
    }

    /// Whether a subagent's tail ends its turn; nil when it ends on results whose call
    /// is out of reach.
    private static func lastWord(in tail: Data) -> Bool? {
        // The results the transcript ends on, while looking for the call they answer.
        var answering: Set<String> = []
        for line in tail.split(separator: UInt8(ascii: "\n")).reversed() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            if !answering.isEmpty {
                guard let tool = toolCall(in: object, answeredBy: answering) else { continue }
                return handbackTools.contains(tool)
            }
            guard let state = ClaudeSessionParser.state(of: object, includingSidechains: true) else { continue }
            if state.endsTheTurn { return true }
            answering = toolResultIDs(in: object)
            if answering.isEmpty { return false }
        }
        return answering.isEmpty ? false : nil
    }

    /// The ids of the tool calls a `user` line brings results for.
    private static func toolResultIDs(in object: [String: Any]) -> Set<String> {
        guard object["type"] as? String == "user",
              let blocks = (object["message"] as? [String: Any])?["content"] as? [[String: Any]]
        else { return [] }
        return Set(blocks.filter { $0["type"] as? String == "tool_result" }.compactMap { $0["tool_use_id"] as? String })
    }

    /// The name of the tool an `assistant` line calls, if it's one of `ids`.
    private static func toolCall(in object: [String: Any], answeredBy ids: Set<String>) -> String? {
        guard object["type"] as? String == "assistant",
              let blocks = (object["message"] as? [String: Any])?["content"] as? [[String: Any]]
        else { return nil }
        return blocks.first { $0["type"] as? String == "tool_use" && ($0["id"] as? String).map(ids.contains) == true }?["name"] as? String
    }

    static func isFinished(_ meta: URL) -> Bool {
        guard let data = try? Data(contentsOf: meta),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        return object["finished"] as? Bool == true
    }

    private static func modificationDate(of file: URL) -> Date? {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    static func tail(of url: URL, bytes: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        try? handle.seek(toOffset: start)
        guard var data = try? handle.readToEnd() else { return nil }
        // Starting mid-line, the first line is a fragment: drop it.
        if start > 0, let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
            data = data.subdata(in: data.index(after: newline)..<data.endIndex)
        }
        return data
    }
}
