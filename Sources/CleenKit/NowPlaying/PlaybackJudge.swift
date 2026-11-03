import Foundation

/// Decides whether the Now Playing source is really playing, from three witnesses that
/// each lie in their own way:
///
/// - MediaRemote's playing flag, the app's own claim. It's the only one that can say
///   "paused", and a `false` from it always wins. But browsers and some players leave it
///   at `true` after pausing, or after the tab that was playing went away.
/// - Core Audio, which knows whether the app is sending sound out. Silence vetoes a
///   `true` claim once it outlasts `grace` (buffering, the gap between two songs, the
///   moment after pressing play). Silence only counts for apps whose sound Cleen can
///   see: browsers (always through helpers) and apps it has already heard play;
///   otherwise the app may play through a daemon, and the claim stands.
/// - Cleen's own play/pause button, which flips the state at once for feedback.
///   - Pause holds until the source goes quiet or says "paused", either of which
///     confirms it for good, or until `pauseWindow` runs out (the command went to another
///     app, or nowhere). Silence after the person's own pause needs no grace: it's the
///     answer, so the state can't bounce back to playing while a browser that keeps its
///     flag at `true` closes its audio stream.
///   - Play holds until sound or a reading that changes to "playing" confirms it, or
///     until `playWindow` runs out. Pressing play also restarts the grace, so a page that
///     takes a moment to start gets the same allowance as a new item; a heartbeat that
///     repeats a stale claim confirms nothing.
///
/// A verdict is *settled* when nothing pending can change it on its own: no grace
/// running, no guess from the button. Only a settled "playing" is worth announcing.
public struct PlaybackJudge: Sendable {
    public struct Verdict: Equatable, Sendable {
        public let isPlaying: Bool
        /// When the verdict may change with no new input; ask again then.
        public let recheckAt: Date?

        public init(isPlaying: Bool, recheckAt: Date?) {
            self.isPlaying = isPlaying
            self.recheckAt = recheckAt
        }

        /// Confirmed by sound, by a claim Core Audio can't check, or by silence that
        /// outlasted the grace, rather than still waiting on one of them.
        public var isSettled: Bool { recheckAt == nil }
    }

    public var grace: TimeInterval = 1.75
    public var playWindow: TimeInterval = 1.5
    public var pauseWindow: TimeInterval = 4

    private var source: Int32?
    private var item: String?
    private var reported = false
    /// When the current claim of playing began.
    private var claimedSince: Date?
    /// nil when Core Audio can't tell for this source.
    private var audible: Bool?
    private var trustsSilence = false
    /// When the source last went quiet (or was last heard, while it's audible).
    private var lastHeard: Date?
    /// Sources heard playing at least once, so their silence means something.
    private var heard: Set<Int32> = []
    private var optimistic: (isPlaying: Bool, until: Date)?
    /// The person paused and the source went quiet: the claim is overruled at once,
    /// until sound, a new item or a new claim.
    private var pauseConfirmed = false

    public init() {}

    /// A reading from MediaRemote: the source app, the item it's on, and its playing flag.
    public mutating func report(source pid: Int32, item: String, isPlaying: Bool, at now: Date) {
        if pid != source {
            source = pid
            reported = false
            claimedSince = nil
            lastHeard = nil
            audible = nil
            optimistic = nil
            pauseConfirmed = false
        }
        let changed = isPlaying != reported
        let newItem = item != self.item
        // A new item gets a fresh grace too: the next song or video may take a moment to
        // buffer, and that silence isn't a pause.
        if isPlaying, changed || claimedSince == nil || newItem { claimedSince = now }
        if !isPlaying { claimedSince = nil }
        if changed || newItem || !isPlaying { pauseConfirmed = false }
        reported = isPlaying
        self.item = item
        // Only news confirms the guess: a "paused", or a claim that just turned to
        // "playing". A heartbeat repeating a stale "playing" says nothing about the button.
        if let guess = optimistic, guess.isPlaying == isPlaying, changed || !isPlaying { optimistic = nil }
    }

    /// What Core Audio says about the current source: making sound, silent, or nil when
    /// it can't tell. `throughHelpers` marks a browser, whose silence is always meaningful.
    public mutating func hear(_ isAudible: Bool?, throughHelpers: Bool, at now: Date) {
        trustsSilence = throughHelpers
        if isAudible == true {
            lastHeard = now
            if let source { heard.insert(source) }
            pauseConfirmed = false
            if optimistic?.isPlaying == true { optimistic = nil }
        } else if audible == true {
            // Just went quiet: the grace starts now.
            lastHeard = now
        }
        audible = isAudible
        if isAudible == false, silenceCounts, let guess = optimistic, !guess.isPlaying, now < guess.until {
            pauseConfirmed = true
            optimistic = nil
        }
    }

    /// The person pressed play/pause on a source that was `wasPlaying`.
    public mutating func expectToggle(from wasPlaying: Bool, at now: Date) {
        if wasPlaying {
            // Already quiet (still inside the grace): that silence is the confirmation.
            if audible == false, silenceCounts {
                pauseConfirmed = true
                optimistic = nil
                return
            }
            optimistic = (false, now.addingTimeInterval(pauseWindow))
        } else {
            optimistic = (true, now.addingTimeInterval(playWindow))
            pauseConfirmed = false
            if reported {
                claimedSince = now
                lastHeard = now
            }
        }
    }

    /// No source any more (nothing is playing): forget the claim and the guess.
    public mutating func reset() {
        source = nil
        item = nil
        reported = false
        claimedSince = nil
        audible = nil
        lastHeard = nil
        optimistic = nil
        pauseConfirmed = false
    }

    public func verdict(at now: Date) -> Verdict {
        if let guess = optimistic, now < guess.until {
            return Verdict(isPlaying: guess.isPlaying, recheckAt: guess.until)
        }
        guard reported else { return Verdict(isPlaying: false, recheckAt: nil) }
        guard audible == false, silenceCounts else { return Verdict(isPlaying: true, recheckAt: nil) }
        if pauseConfirmed { return Verdict(isPlaying: false, recheckAt: nil) }
        let quietSince = max(lastHeard ?? .distantPast, claimedSince ?? now)
        let deadline = quietSince.addingTimeInterval(grace)
        return now < deadline ? Verdict(isPlaying: true, recheckAt: deadline) : Verdict(isPlaying: false, recheckAt: nil)
    }

    /// Whether this source's silence means it isn't playing.
    private var silenceCounts: Bool {
        trustsSilence || source.map(heard.contains) == true
    }
}
