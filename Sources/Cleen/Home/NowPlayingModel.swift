import AppKit
import CleenKit
import Observation

/// Whatever the Mac is playing — a YouTube tab, Spotify, Music, a podcast — read from
/// the system's Now Playing through `NowPlayingBridge`.
///
/// "Playing" means sound is coming out, not just that the app says so: `PlaybackJudge`
/// weighs the app's claim against Core Audio (`AudioProcessMonitor`) and against the
/// guess made when the play/pause button is pressed. The artwork and the app's name and
/// icon always belong to the reading on screen, never to the source before it.
@Observable
final class NowPlayingModel {
    private(set) var track: NowPlayingTrack?
    /// Told when the item or its playing state changes (the notch's song banner), once
    /// the change stands: see `announce`.
    @ObservationIgnored var onTrackChange: (NowPlayingTrack?) -> Void = { _ in }
    private(set) var artwork: NSImage?
    /// The app playing it, for its name and icon.
    private(set) var appName: String?
    private(set) var appURL: URL?
    /// The artwork is a site's icon rather than cover art; shown inset, not cropped.
    private(set) var artworkIsIcon = false
    @ObservationIgnored private var appBundleID: String?
    /// The app the current reading comes from; the identity above was read for it.
    @ObservationIgnored private var sourcePID: Int32?
    /// The helper's key for `artwork`, when it is the player's own artwork.
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var iconIdentity: String?

    /// The last reading as MediaRemote gave it, and the one `track` was derived from.
    @ObservationIgnored private var reading: NowPlayingTrack?
    @ObservationIgnored private var shownReading: NowPlayingTrack?
    @ObservationIgnored private var judge = PlaybackJudge()
    /// Core Audio's latest list; nil until it first answers.
    @ObservationIgnored private var processes: [AudioProcess]?
    @ObservationIgnored private var recheck: Task<Void, Never>?
    /// What `onTrackChange` was last told.
    @ObservationIgnored private var announced: Announcement?

    @ObservationIgnored private let bridge = NowPlayingBridge()
    @ObservationIgnored private let audio = AudioProcessMonitor()
    @ObservationIgnored private var isStreaming = false
    @ObservationIgnored private var restartDelay = NowPlayingModel.firstRestartDelay
    @ObservationIgnored private var bridgeStartedAt = ContinuousClock.now

    private static let firstRestartDelay = Duration.seconds(2)
    /// A helper that ran this long before dying wasn't crash-looping: start over at the
    /// first delay rather than keep backing off.
    private static let stableUptime = Duration.seconds(30)

    private struct Announcement: Equatable {
        let identity: String
        let isPlaying: Bool
    }

    /// Starts listening the first time someone shows Now Playing; the helper and the
    /// Core Audio listeners are event-driven and nearly free, so they then keep running.
    func watch() async {
        guard !isStreaming else { return }
        isStreaming = true
        startBridge()
        audio.start { [weak self] processes in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.audioChanged(processes) } }
        }
    }

    func send(_ command: NowPlayingCommand) async {
        var command = command
        if command == .playPause, let track {
            // Ask for what the button shows rather than a toggle: when the app claims to
            // be playing but is silent, "play" still means play. The button flips right
            // away; the stream confirms it, or the guess runs out and the truth returns.
            command = track.isPlaying ? .pause : .play
            judge.expectToggle(from: track.isPlaying, at: .now)
            resolve()
        }
        await NowPlayingBridge.send(command)
    }

    // MARK: Sources

    private func startBridge() {
        bridgeStartedAt = .now
        bridge.start(
            onUpdate: { [weak self] reading, artworkData in self?.apply(reading, artworkData: artworkData) },
            onExit: { [weak self] in self?.helperExited() }
        )
    }

    /// The helper died: what it said last can't be trusted to still be true, so the
    /// player empties, and the helper comes back (later each time, should it keep dying).
    /// The bridge reports the exit only after the helper's last lines, so nothing it said
    /// can land after this and put a dead reading back on screen.
    private func helperExited() {
        clear()
        if ContinuousClock.now - bridgeStartedAt >= Self.stableUptime { restartDelay = Self.firstRestartDelay }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, .seconds(60))
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.startBridge()
        }
    }

    private func apply(_ next: NowPlayingTrack?, artworkData: Data?) {
        // MediaRemote can keep naming an app that already quit.
        guard let next, Self.isRunning(next.pid) else {
            clear()
            return
        }
        if next.pid != sourcePID { adopt(next.pid) }
        judge.report(source: next.pid, item: next.identity, isPlaying: next.isPlaying, at: .now)
        hearSource()
        // Artwork first, so the banner that `track` may trigger shows the right one.
        updateArtwork(for: next, data: artworkData)
        reading = next
        resolve()
    }

    private func audioChanged(_ processes: [AudioProcess]) {
        self.processes = processes
        guard reading != nil else { return }
        hearSource()
        resolve()
    }

    /// A new app is the source: its own name and icon, and none of the last one's artwork.
    private func adopt(_ pid: Int32) {
        sourcePID = pid
        let app = NSRunningApplication(processIdentifier: pid)
        appName = app?.localizedName
        appURL = app?.bundleURL
        appBundleID = app?.bundleIdentifier
        artwork = nil
        artworkKey = nil
        artworkIsIcon = false
        iconIdentity = nil
    }

    private func clear() {
        recheck?.cancel()
        recheck = nil
        judge.reset()
        reading = nil
        shownReading = nil
        sourcePID = nil
        track = nil
        announce(nil, settled: true)
        artwork = nil
        artworkKey = nil
        appName = nil
        appURL = nil
        appBundleID = nil
        artworkIsIcon = false
        iconIdentity = nil
    }

    private func hearSource() {
        guard let sourcePID else { return }
        let audible = processes.flatMap { NowPlayingAudio.isAudible(pid: sourcePID, bundleID: appBundleID, in: $0) }
        judge.hear(audible, throughHelpers: NowPlayingAudio.playsThroughHelpers(appBundleID), at: .now)
    }

    /// Publishes the judge's verdict, and asks again when it may change on its own (the
    /// end of the grace for silence, or of the button's guess).
    private func resolve() {
        recheck?.cancel()
        recheck = nil
        guard let reading else { return }
        let now = Date.now
        let verdict = judge.verdict(at: now)
        // The same reading with the same verdict: keep what's shown rather than restamp it.
        if reading != shownReading || track?.isPlaying != verdict.isPlaying {
            shownReading = reading
            track = reading.playing(verdict.isPlaying, at: now)
        }
        announce(track, settled: verdict.isSettled)
        guard let recheckAt = verdict.recheckAt else { return }
        recheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, recheckAt.timeIntervalSinceNow) + 0.05))
            guard !Task.isCancelled else { return }
            self?.resolve()
        }
    }

    /// Tells `onTrackChange` about a new item or a new playing state once it stands. A
    /// "playing" still inside its grace, or only the button's guess, may yet turn out
    /// silent (a tab whose flag was left at playing, a video still buffering), so it waits
    /// until sound or the end of the grace settles it; then a late start is still
    /// announced. Stopping is told at once.
    private func announce(_ track: NowPlayingTrack?, settled: Bool) {
        if let track, track.isPlaying, !settled { return }
        let state = track.map { Announcement(identity: $0.identity, isPlaying: $0.isPlaying) }
        guard state != announced else { return }
        announced = state
        onTrackChange(track)
    }

    // MARK: Artwork

    private func updateArtwork(for next: NowPlayingTrack, data: Data?) {
        // A page playing with no metadata of its own: the browser's artwork is just its
        // engine logo, so show the tab's site icon instead.
        if BrowserTabIcon.isBrowser(appBundleID), next.artist.isEmpty, next.album.isEmpty {
            guard next.identity != iconIdentity else { return }
            iconIdentity = next.identity
            // Whatever was shown belongs to another page; nothing until this one's icon.
            artwork = nil
            artworkKey = nil
            artworkIsIcon = false
            guard let bundleID = appBundleID else { return }
            Task {
                guard let icon = await BrowserTabIcon.icon(bundleID: bundleID, tabTitle: next.title),
                      self.reading?.identity == next.identity
                else { return }
                self.artwork = icon
                self.artworkIsIcon = true
            }
            return
        }
        iconIdentity = nil
        if artworkIsIcon {
            artwork = nil
            artworkIsIcon = false
        }
        if let key = next.artworkKey {
            // The same image again (players resend it after leaving it out): keep the one
            // shown so it doesn't flash.
            guard key != artworkKey || artwork == nil else { return }
            artwork = data.flatMap(NSImage.init(data:))
            artworkKey = artwork == nil ? nil : key
        } else if next.identity != reading?.identity {
            // A new item without artwork; an update of the same item without it
            // (players omit it while paused) keeps the one already shown.
            artwork = nil
            artworkKey = nil
        }
    }

    /// Whether the process is still there (0 and below: MediaRemote named no process).
    private static func isRunning(_ pid: Int32) -> Bool {
        pid <= 0 || kill(pid, 0) == 0 || errno == EPERM
    }
}
