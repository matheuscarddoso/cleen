import Foundation

/// A Claude Code session as its transcript tells it: what it's called, where it runs,
/// and whether it's working, waiting on the person, or stopped.
public struct ClaudeSession: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        // Busy: the session is doing something.

        /// The model is writing (a prompt or a tool result just went in).
        case thinking
        /// A tool call is out and hasn't come back: running, or waiting for permission
        /// (the permission itself only shows through the hook, in the app).
        case running(tool: String)
        /// Background work is still going for it, even though the session's own turn may
        /// have ended ("Waiting for 1 dynamic workflow"). `agents` counts every agent at
        /// work, the workflows' included; `workflows` counts the runs still going.
        case delegating(agents: Int, workflows: Int)

        // The person is wanted right now.

        /// Claude asked a question (AskUserQuestion) and waits for the answer.
        case asking
        /// Claude finished a plan (ExitPlanMode) and waits for it to be approved.
        case reviewingPlan

        // The person's turn.

        /// The turn ended: Claude is waiting for the next message.
        case waiting
        /// The person stopped the turn (Esc, or a rejected tool call).
        case interrupted
        /// The turn stopped on an API error (limits, overload, a bad request).
        case failed

        public var isBusy: Bool {
            switch self {
            case .thinking, .running, .delegating: true
            case .asking, .reviewingPlan, .waiting, .interrupted, .failed: false
            }
        }

        /// Claude can't go on until the person answers something.
        public var needsAnswer: Bool { self == .asking || self == .reviewingPlan }

        /// Worth telling the person about when a busy session lands here: the turn is
        /// over, a question waits, or it broke. An interruption is theirs, so it's no news.
        public var callsForThePerson: Bool {
            switch self {
            case .waiting, .asking, .reviewingPlan, .failed: true
            case .thinking, .running, .delegating, .interrupted: false
            }
        }

        /// The turn is over, however it ended: what a subagent's last word needs to say
        /// for it to stop counting as at work.
        var endsTheTurn: Bool { self == .waiting || self == .interrupted || self == .failed }
    }

    /// The transcript's file name: Claude Code's session id.
    public let id: String
    /// Claude Code's own title for the conversation, or the folder it runs in.
    public let title: String
    /// The working directory.
    public let directory: String?
    public let state: State
    /// When the transcript, or any background work for it, last changed.
    public let updatedAt: Date
    /// When the current state began (the last event's timestamp).
    public let since: Date
    /// The current turn's steps and Claude's latest sentence.
    public let activity: ClaudeActivity

    /// The same session with background work going. It outranks a turn that's over and
    /// a call that's only waiting on it, not one the session itself is running, a
    /// question for the person, or an error they need to see.
    public func delegating(agents: Int, workflows: Int) -> ClaudeSession {
        let state: State = switch self.state {
        case .waiting, .interrupted, .delegating: .delegating(agents: agents, workflows: workflows)
        case .running(let tool) where ["Agent", "Task", "Workflow"].contains(tool): .delegating(agents: agents, workflows: workflows)
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
