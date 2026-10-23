import Foundation

/// A plain countdown, or Pomodoro's focus and break rounds.
public enum TimerMode: String, Codable, Sendable, CaseIterable {
    case countdown
    case pomodoro
}

/// What the running stretch of time is for.
public enum TimerPhase: String, Codable, Sendable {
    case countdown
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// The Pomodoro rhythm: focus, short break, and a long break after every few rounds.
public struct PomodoroPlan: Codable, Sendable, Equatable {
    public var focus: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    /// Focus rounds per cycle; the last one is followed by the long break.
    public var rounds: Int

    public init(focus: TimeInterval, shortBreak: TimeInterval, longBreak: TimeInterval, rounds: Int) {
        self.focus = focus
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.rounds = max(1, rounds)
    }

    /// 25 min focus, 5 min break, 15 min after the fourth round.
    public static let standard = PomodoroPlan(focus: 25 * 60, shortBreak: 5 * 60, longBreak: 15 * 60, rounds: 4)

    public func duration(of phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .countdown, .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    /// The phase and round that follow `phase` in `round` (1-based).
    public func next(after phase: TimerPhase, round: Int) -> (phase: TimerPhase, round: Int) {
        switch phase {
        case .focus, .countdown: round >= rounds ? (.longBreak, round) : (.shortBreak, round)
        case .shortBreak: (.focus, min(round + 1, rounds))
        case .longBreak: (.focus, 1)
        }
    }
}

/// One timer's whole state as a value, so it can be persisted and tested without a
/// clock. Running means `endDate` is set; paused means `pausedRemaining` is; neither is
/// idle, ready to start at `duration`. Time is never ticked: everything is derived from
/// the dates passed in.
public struct TimerSession: Codable, Sendable, Equatable {
    public private(set) var mode: TimerMode
    public private(set) var phase: TimerPhase
    /// The Pomodoro round, 1-based. Stays 1 in countdown mode.
    public private(set) var round: Int
    /// The length of the current phase, including minutes added while it runs.
    public private(set) var duration: TimeInterval
    /// When the running phase ends.
    public private(set) var endDate: Date?
    /// What was left when it was paused.
    public private(set) var pausedRemaining: TimeInterval?
    /// The length picked for countdowns; kept across modes and resets.
    public private(set) var countdownLength: TimeInterval
    public let plan: PomodoroPlan

    public static let minimumLength: TimeInterval = 60
    public static let maximumLength: TimeInterval = 180 * 60

    public init(countdownLength: TimeInterval = 10 * 60, plan: PomodoroPlan = .standard) {
        let length = Self.clamp(countdownLength)
        self.mode = .countdown
        self.phase = .countdown
        self.round = 1
        self.duration = length
        self.countdownLength = length
        self.plan = plan
    }

    public var isRunning: Bool { endDate != nil }
    public var isPaused: Bool { pausedRemaining != nil }
    /// Running or paused: something has been started and not reset.
    public var isActive: Bool { isRunning || isPaused }

    /// Whether `reset()` would change anything: something is under way, or Pomodoro
    /// is waiting at a later phase or round (after a skip or a relaunch).
    public var canReset: Bool {
        isActive || round != 1 || phase != (mode == .pomodoro ? .focus : .countdown)
    }

    public func remaining(at date: Date) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        if let pausedRemaining { return pausedRemaining }
        return duration
    }

    /// How much of the phase has gone by, 0 at the start and 1 at the end.
    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: date) / duration))
    }

    public func isFinished(at date: Date) -> Bool {
        guard let endDate else { return false }
        return endDate <= date
    }

    // MARK: Changes

    public mutating func start(at date: Date) {
        guard !isRunning else { return }
        endDate = date.addingTimeInterval(remaining(at: date))
        pausedRemaining = nil
    }

    public mutating func pause(at date: Date) {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSince(date))
        self.endDate = nil
    }

    /// Start, pause or resume, whichever comes next.
    public mutating func toggle(at date: Date) {
        isRunning ? pause(at: date) : start(at: date)
    }

    /// Back to idle at the first phase, keeping the mode and the picked length.
    public mutating func reset() {
        endDate = nil
        pausedRemaining = nil
        round = 1
        phase = mode == .pomodoro ? .focus : .countdown
        duration = length(of: phase)
    }

    /// One more minute on the clock. Idle, it lengthens the countdown about to start.
    public mutating func addMinute(at date: Date) {
        if let endDate {
            self.endDate = endDate.addingTimeInterval(60)
            duration += 60
        } else if let pausedRemaining {
            self.pausedRemaining = pausedRemaining + 60
            duration += 60
        } else if mode == .countdown {
            setCountdownLength(countdownLength + 60)
        }
    }

    /// Switching modes starts over; the views only offer it while idle.
    public mutating func setMode(_ newMode: TimerMode) {
        guard newMode != mode else { return }
        mode = newMode
        reset()
    }

    /// Picks the countdown's length. Ignored while a countdown is under way.
    public mutating func setCountdownLength(_ length: TimeInterval) {
        countdownLength = Self.clamp(length)
        if mode == .countdown, !isActive { duration = countdownLength }
    }

    /// Ends the current phase. A countdown goes back to idle; Pomodoro moves to the next
    /// phase and keeps going on its own when `autoStart` is set. Returns the phase that
    /// ended.
    @discardableResult
    public mutating func finishPhase(at date: Date, autoStart: Bool = true) -> TimerPhase {
        let ended = phase
        guard mode == .pomodoro else {
            reset()
            return ended
        }
        let next = plan.next(after: phase, round: round)
        phase = next.phase
        round = next.round
        duration = length(of: next.phase)
        pausedRemaining = nil
        endDate = autoStart ? date.addingTimeInterval(duration) : nil
        return ended
    }

    /// Skips to the next Pomodoro phase, carrying on in the same running/idle state.
    public mutating func skip(at date: Date) {
        guard mode == .pomodoro else { return }
        finishPhase(at: date, autoStart: isRunning)
    }

    /// After a relaunch: a phase that ended while Cleen was closed finishes quietly, and
    /// the next one waits for the person instead of starting behind their back.
    public mutating func settle(at date: Date) {
        if isFinished(at: date) { finishPhase(at: date, autoStart: false) }
    }

    private func length(of phase: TimerPhase) -> TimeInterval {
        phase == .countdown ? countdownLength : plan.duration(of: phase)
    }

    private static func clamp(_ length: TimeInterval) -> TimeInterval {
        min(maximumLength, max(minimumLength, length.rounded()))
    }
}

/// Clock text for a countdown: `25:00`, `0:07`, and `1:40:00` past 99 minutes.
public enum TimerClock {
    /// Rounds up, so a fresh 25-minute timer reads 25:00 and the last second reads 0:01
    /// rather than 0:00.
    public static func string(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let hours = total / 3600
        let minutes = total / 60
        let secs = total % 60
        if minutes >= 100 {
            return String(format: "%ld:%02ld:%02ld", hours, minutes % 60, secs)
        }
        return String(format: "%ld:%02ld", minutes, secs)
    }

    /// `25 min`, `1h`, `1h 30min`: a length as the person picked it.
    public static func length(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return String(localized: "\(minutes) min") }
        return minutes % 60 == 0 ? String(localized: "\(minutes / 60)h") : String(localized: "\(minutes / 60)h \(minutes % 60)min")
    }
}
