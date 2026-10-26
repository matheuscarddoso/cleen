import AppKit
import CleenKit
import SwiftUI
import CoreAudio
import EventKit
import Observation

/// Watches for the moments the closed notch should show — power plugged in or out,
/// headphones connecting, a new song, a meeting about to start — and decides what's on
/// it right now. Each kind can be turned off in Ajustes › Aparência.
@Observable
final class LiveActivityCenter {
    /// The banner on screen, if any.
    private(set) var banner: LiveActivity?
    /// A meeting starting within the next few minutes (or just started).
    private(set) var meeting: LiveActivity?
    /// Downloads in progress, with their real progress and time left.
    let downloads = DownloadWatcher()

    /// The download the closed notch follows, when downloads are shown.
    var download: DownloadWatcher.Download? {
        LiveActivitySettings.downloads ? downloads.active.first : nil
    }

    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var powerWatcher: PowerSourceWatcher?
    @ObservationIgnored private var audioListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var lastPower: BatteryStats?
    @ObservationIgnored private var wirelessOutputs: [AudioObjectID: String] = [:]
    @ObservationIgnored private var lastTrack: String?
    @ObservationIgnored private var meetingLoop: Task<Void, Never>?

    static let bannerDuration = Duration.seconds(3.2)
    /// How early a meeting shows up, and how long after its start it stays.
    static let meetingLead: TimeInterval = 10 * 60
    static let meetingTail: TimeInterval = 2 * 60

    func start(agenda: AgendaModel) {
        guard powerWatcher == nil else { return }
        lastPower = BatteryStats.read()
        powerWatcher = PowerSourceWatcher { [weak self] in
            MainActor.assumeIsolated { self?.powerChanged() }
        }
        wirelessOutputs = Self.wireless(AudioOutputDevices.current())
        audioListener = AudioOutputDevices.watch { [weak self] in
            MainActor.assumeIsolated { self?.audioDevicesChanged() }
        }
        downloads.onFinished = { [weak self] url, announced in
            guard LiveActivitySettings.downloads else { return }
            let onDisk = (try? url.resourceValues(forKeys: [.totalFileSizeKey, .fileSizeKey])).flatMap { $0.totalFileSize ?? $0.fileSize } ?? 0
            self?.show(.downloaded(url: url, size: max(Int64(onDisk), announced)), for: .seconds(4.5))
        }
        downloads.start()
        meetingLoop = Task { [weak self] in
            // The agenda only loads once Calendar access is already granted; the
            // notch never asks for it on its own.
            if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                Task { await agenda.watch() }
            }
            while !Task.isCancelled {
                self?.updateMeeting(agenda: agenda)
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    // MARK: Sources

    private func powerChanged() {
        guard let now = BatteryStats.read() else { return }
        defer { lastPower = now }
        guard LiveActivitySettings.power, let before = lastPower else { return }
        if now.isPluggedIn != before.isPluggedIn {
            show(.power(now.isPluggedIn ? .charging : .unplugged, level: now.level))
        } else if now.isPluggedIn, now.level >= 0.995, before.level < 0.995 {
            show(.power(.full, level: now.level))
        } else if !now.isPluggedIn, [0.2, 0.1].contains(where: { now.level <= $0 && before.level > $0 }) {
            show(.power(.low, level: now.level))
        }
    }

    private func audioDevicesChanged() {
        let now = Self.wireless(AudioOutputDevices.current())
        defer { wirelessOutputs = now }
        guard LiveActivitySettings.headphones else { return }
        if let added = now.first(where: { wirelessOutputs[$0.key] == nil }) {
            show(.headphones(name: added.value, connected: true))
        } else if let removed = wirelessOutputs.first(where: { now[$0.key] == nil }) {
            show(.headphones(name: removed.value, connected: false))
        }
    }

    /// A message from someone else arrived in Messages.
    func messageArrived(_ message: ChatMessage) {
        guard LiveActivitySettings.messages else { return }
        show(.message(message), for: .seconds(6))
    }

    /// The message on the island, if one is showing: opening the notch goes to it.
    var shownMessage: ChatMessage? {
        if case .message(let message) = banner { return message }
        return nil
    }

    /// Called by the timer when a countdown or a Pomodoro phase runs out.
    func timerEnded(phase: String) {
        show(.timerEnded(phase: phase))
    }

    /// Confirms a copy the person can't see happen (the notch is closed by then).
    func copied(_ text: String, color: NSColor? = nil) {
        show(.copied(text: text, color: color))
    }

    /// Says how a command run from the search went, once the notch has closed.
    func notice(_ title: String, detail: String, symbol: String) {
        show(.notice(title: title, detail: detail, symbol: symbol))
    }

    /// Called by the player when what's playing changes.
    func trackChanged(_ track: NowPlayingTrack?) {
        guard let track, track.isPlaying else { return }
        let identity = "\(track.title)|\(track.artist)"
        defer { lastTrack = identity }
        // The first song after launch isn't news, and neither is pause/resume.
        guard lastTrack != nil, identity != lastTrack, LiveActivitySettings.track, !track.title.isEmpty else { return }
        show(.track(title: track.title, artist: track.artist))
    }

    private func updateMeeting(agenda: AgendaModel) {
        guard LiveActivitySettings.meeting else {
            meeting = nil
            return
        }
        let now = Date.now
        let next = agenda.events(on: Calendar.current.startOfDay(for: now))
            .filter { !$0.isAllDay }
            .first { event in
                let lead = event.start.timeIntervalSince(now)
                return lead <= Self.meetingLead && lead >= -Self.meetingTail
            }
        let activity = next.map { LiveActivity.meeting(title: $0.title, start: $0.start, color: $0.color) }
        if activity != meeting { meeting = activity }
    }

    /// A sample of each kind, for checking the UI (`--live <kind>`).
    func preview(_ kind: String) {
        switch kind {
        case "power": show(.power(.charging, level: 0.82))
        case "low": show(.power(.low, level: 0.1))
        case "headphones": show(.headphones(name: "AirPods Pro de Matheus", connected: true))
        case "track": show(.track(title: "Clair de Lune", artist: "Claude Debussy"))
        case "meeting": meeting = .meeting(title: "Daily", start: .now.addingTimeInterval(5 * 60), color: .systemPurple)
        case "message":
            show(.message(ChatMessage(id: 0, chatGUID: "preview", chatName: nil, handle: "Sam Rivera", text: "Coffee there Friday?", date: .now, isFromMe: false, isGroup: false, imagePath: nil, service: "iMessage")), for: .seconds(6))
        case "download":
            let url = URL.downloadsDirectory.appending(path: "Launch Assets.zip")
            show(.downloaded(url: url, size: 1_480_000_000), for: .seconds(4.5))
        default: break
        }
    }

    // MARK: Banner

    private func show(_ activity: LiveActivity, for duration: Duration = bannerDuration) {
        bannerTask?.cancel()
        withAnimation(NotchStyle.liveSpring) { banner = activity }
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            withAnimation(NotchStyle.liveExit) { self?.banner = nil }
        }
    }

    private static func wireless(_ devices: [AudioOutputDevices.Device]) -> [AudioObjectID: String] {
        Dictionary(devices.filter(\.isWireless).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }
}
