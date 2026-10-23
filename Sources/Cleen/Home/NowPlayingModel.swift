import AppKit
import Observation

/// Whatever the Mac is playing — a YouTube tab, Spotify, Music, a podcast — read from
/// the system's Now Playing through `NowPlayingBridge`.
@Observable
final class NowPlayingModel {
    private(set) var track: NowPlayingTrack? {
        didSet { if track?.identity != oldValue?.identity || track?.isPlaying != oldValue?.isPlaying { onTrackChange(track) } }
    }
    /// Told when the item or its playing state changes (the notch's song banner).
    @ObservationIgnored var onTrackChange: (NowPlayingTrack?) -> Void = { _ in }
    private(set) var artwork: NSImage?
    /// The app playing it, for its name and icon.
    private(set) var appName: String?
    private(set) var appURL: URL?
    /// The artwork is a site's icon rather than cover art; shown inset, not cropped.
    private(set) var artworkIsIcon = false
    @ObservationIgnored private var appBundleID: String?
    @ObservationIgnored private var iconIdentity: String?

    @ObservationIgnored private let bridge = NowPlayingBridge()
    @ObservationIgnored private var isStreaming = false

    /// Starts listening the first time someone shows Now Playing; the helper is
    /// event-driven and nearly free, so it then keeps running.
    func watch() async {
        guard !isStreaming else { return }
        isStreaming = true
        bridge.start { [weak self] json in
            let reading = NowPlayingTrack(json: json)
            let artworkData = (json["artwork"] as? String).flatMap { Data(base64Encoded: $0) }
            Task { @MainActor in self?.apply(reading, artworkData: artworkData) }
        }
    }

    func position(at date: Date) -> TimeInterval {
        track?.position(at: date) ?? 0
    }

    func send(_ command: NowPlayingCommand) async {
        // Flip the button right away; the stream confirms (or corrects) a moment later.
        if command == .playPause, let track {
            self.track = track.toggled()
        }
        await NowPlayingBridge.send(command)
    }

    private func apply(_ reading: NowPlayingTrack?, artworkData: Data?) {
        guard let reading else {
            track = nil
            artwork = nil
            appName = nil
            appURL = nil
            artworkIsIcon = false
            iconIdentity = nil
            return
        }
        if reading.pid != track?.pid {
            let app = NSRunningApplication(processIdentifier: reading.pid)
            appName = app?.localizedName
            appURL = app?.bundleURL
            appBundleID = app?.bundleIdentifier
        }
        // A page playing with no metadata of its own: the browser's artwork is just its
        // engine logo, so show the tab's site icon instead.
        if BrowserTabIcon.isBrowser(appBundleID), reading.artist.isEmpty, reading.album.isEmpty {
            track = reading
            guard reading.identity != iconIdentity, let bundleID = appBundleID else { return }
            iconIdentity = reading.identity
            Task {
                guard let icon = await BrowserTabIcon.icon(bundleID: bundleID, tabTitle: reading.title),
                      self.track?.identity == reading.identity
                else { return }
                self.artwork = icon
                self.artworkIsIcon = true
            }
            return
        }
        if artworkIsIcon, reading.identity != iconIdentity {
            artworkIsIcon = false
            iconIdentity = nil
        }
        if let artworkData, let image = NSImage(data: artworkData) {
            artwork = image
        } else if reading.artworkKey == nil, reading.identity != track?.identity {
            // A new item without artwork; an update of the same item without it
            // (players omit it while paused) keeps the one already shown.
            artwork = nil
        }
        track = reading
    }
}
