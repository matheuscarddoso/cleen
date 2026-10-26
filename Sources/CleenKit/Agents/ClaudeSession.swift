import Foundation

/// A Claude Code session as its transcript tells it: what it's called, where it runs,
/// and whether it's working or waiting for the person.
public struct ClaudeSession: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        /// The model is writing (a prompt or a tool result just went in).
        case thinking
        /// A tool call is out and hasn't come back: running, or waiting for permission.
        case running(tool: String)
        /// Background agents (subagents, a workflow) are still at work for it, even though
        /// the session's own turn may have ended ("Waiting for 1 dynamic workflow").
        case delegating(agents: Int)
        /// The turn ended: Claude is waiting for the next message.
        case waiting

        public var isBusy: Bool { self != .waiting }
    }

    /// The transcript's file name: Claude Code's session id.
    public let id: String
    /// Claude Code's own title for the conversation, or the folder it runs in.
    public let title: String
    /// The working directory.
    public let directory: String?
    public let state: State
    /// When the transcript last changed.
    public let updatedAt: Date
    /// When the current state began (the last event's timestamp).
    public let since: Date
    /// The current turn's steps and Claude's latest sentence.
    public let activity: ClaudeActivity

    /// The same session with background agents at work: they outrank a turn that
    /// ended or a call that's only waiting on them, not one the session itself is running.
    public func delegating(_ agents: Int) -> ClaudeSession {
        let state: State = switch self.state {
        case .waiting, .delegating: .delegating(agents: agents)
        case .running(let tool) where ["Agent", "Task", "Workflow"].contains(tool): .delegating(agents: agents)
        default: self.state
        }
        return ClaudeSession(id: id, title: title, directory: directory, state: state, updatedAt: updatedAt, since: since, activity: activity)
    }

    public var projectName: String? {
        directory.map { URL(filePath: $0).lastPathComponent }
    }

    public init(id: String, title: String, directory: String?, state: State, updatedAt: Date, since: Date, activity: ClaudeActivity = .empty) {
        self.id = id
        self.title = title
        self.directory = directory
        self.state = state
        self.updatedAt = updatedAt
        self.since = since
        self.activity = activity
    }
}
