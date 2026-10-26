import AppKit
import os
import CleenKit
import Observation

/// Takes over the volume and brightness keys (when the person turns it on in Ajustes ›
/// Aparência) and shows the level on the notch instead of the system's square in the
/// middle of the screen. Volume moves the default output, brightness the display under
/// the pointer. Needs Accessibility for the event tap.
@Observable
final class MediaKeyHUD {
    enum Kind: Equatable {
        case volume
        case brightness
    }

    /// What the notch shows while a key is being pressed.
    struct Reading: Equatable {
        var kind: Kind
        var level: Double
        var isMuted: Bool
        /// The screen whose brightness changed.
        var source: CGDirectDisplayID?
        /// The notch it shows on.
        var display: CGDirectDisplayID?

        var isSilent: Bool { kind == .volume && (isMuted || level <= 0.0001) }
    }

    private(set) var reading: Reading?
    /// On in Ajustes, but Accessibility hasn't been granted yet.
    private(set) var isWaitingForAccess = false

    @ObservationIgnored private let displays: DisplaysModel
    @ObservationIgnored private var tap: MediaKeyTap?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var accessPoll: Task<Void, Never>?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?

    static let enabledKey = "notchReplacesSystemHUD"
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "media-keys")
    static let duration = Duration.seconds(1.5)
    /// Wide enough for the symbol on the left and a bar with its percentage on the right.
    static let wingWidth = 112.0

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    init(displays: DisplaysModel) {
        self.displays = displays
    }

    /// At launch: listens if it was left on (without asking for anything).
    func start() {
        update(prompting: false)
    }

    /// Follows the switch in Ajustes. Turning it on is when Accessibility is asked for.
    func update(prompting: Bool) {
        guard Self.isEnabled else {
            uninstall()
            return
        }
        guard tap == nil else { return }
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": prompting] as CFDictionary)
        let installed = trusted && install()
        Self.log.notice("media keys: accessibility \(trusted ? "granted" : "missing", privacy: .public), tap \(installed ? "on" : "off", privacy: .public)")
        if installed {
            isWaitingForAccess = false
            accessPoll?.cancel()
            accessPoll = nil
        } else {
            isWaitingForAccess = true
            pollForAccess()
        }
    }

    /// The grant happens in System Settings, outside Cleen: look again every second and
    /// start the moment it comes through.
    private func pollForAccess() {
        guard accessPoll == nil else { return }
        accessPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, Self.isEnabled else { return }
                if AXIsProcessTrusted() {
                    self.accessPoll = nil
                    self.update(prompting: false)
                    return
                }
            }
        }
    }

    @discardableResult
    private func install() -> Bool {
        let tap = MediaKeyTap.start { [weak self] press, fine in
            // On the tap's thread. Volume is applied right here (Core Audio is
            // thread-safe), brightness on the main thread where the displays live.
            let hud = self
            if press.key.isVolume {
                return Self.handleVolume(press, fine: fine) { reading in
                    DispatchQueue.main.async { MainActor.assumeIsolated { hud?.show(reading) } }
                }
            }
            if press.isDown {
                let up = press.key == .brightnessUp
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { hud?.stepBrightness(up: up, fine: fine) }
                }
            }
            return true
        }
        guard let tap else { return false }
        self.tap = tap
        // External monitors take a moment to answer over the cable; read them now so the
        // first brightness press is instant.
        if displays.items.isEmpty { Task { await displays.load() } }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        return true
    }

    private func uninstall() {
        accessPoll?.cancel()
        accessPoll = nil
        isWaitingForAccess = false
        tap?.stop()
        tap = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        hideTask?.cancel()
        reading = nil
    }

    private func screensChanged() {
        Task { await displays.load() }
    }

    // MARK: Volume

    /// Steps the default output; false (the key goes on to macOS) when its volume
    /// can't be set from here, as with most HDMI outputs.
    private nonisolated static func handleVolume(_ press: MediaKey.Press, fine: Bool, show: (Reading) -> Void) -> Bool {
        guard let device = SystemVolume.defaultOutput(), SystemVolume.canSetVolume(device) else { return false }
        if press.key == .mute, !SystemVolume.canMute(device) { return false }
        guard press.isDown else { return true }
        // Held mute doesn't flicker on and off.
        if press.key == .mute, press.isRepeat { return true }
        guard let before = SystemVolume.read(device) else { return false }
        let after = before.applying(press.key, fine: fine)
        SystemVolume.write(after, to: device, from: before)
        show(Reading(kind: .volume, level: after.level, isMuted: after.isMuted, source: nil, display: nil))
        return true
    }

    // MARK: Brightness

    private func stepBrightness(up: Bool, fine: Bool) {
        guard let screen = Self.screenUnderPointer, let id = screen.displayID else { return }
        guard let item = displays.items.first(where: { $0.id == id }) else {
            // A display that wasn't there when they were last read: read again, then
            // apply the press (once, so a display that never shows up can't loop).
            guard !displays.isLoading else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.displays.load()
                if self.displays.items.contains(where: { $0.id == id }) { self.stepBrightness(up: up, fine: fine) }
            }
            return
        }
        // Mid-burst the last value Cleen set is the truth (the write may not have
        // landed yet); at the start of one, the panel's own level (auto-brightness
        // moves it) is.
        let current: Double = if let reading, reading.kind == .brightness, reading.source == id {
            item.brightness
        } else if item.control == .builtIn {
            BuiltInBrightness.get(id) ?? item.brightness
        } else {
            item.brightness
        }
        displays.setBrightness(LevelStep.next(current, up: up, fine: fine), for: id)
        let level = displays.items.first(where: { $0.id == id })?.brightness ?? current
        show(Reading(kind: .brightness, level: level, isMuted: false, source: id, display: nil))
    }

    // MARK: Showing

    /// Volume, then brightness, stepping up a few times, for checking the look
    /// (`--live volume`).
    func preview() {
        Task {
            for step in 0..<6 {
                show(Reading(kind: .volume, level: 0.41 + Double(step) * 0.05, isMuted: false, source: nil, display: nil))
                try? await Task.sleep(for: .milliseconds(260))
            }
            for step in 0..<5 {
                show(Reading(kind: .brightness, level: 0.5 + Double(step) * 0.06, isMuted: false, source: nil, display: nil))
                try? await Task.sleep(for: .milliseconds(260))
            }
        }
    }

    private func show(_ new: Reading) {
        var new = new
        new.display = Self.notchDisplay(for: new.source ?? Self.screenUnderPointer?.displayID)
        reading = new
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            self?.reading = nil
        }
    }

    /// The reading for one notch: the screen it's about if Cleen draws a notch there,
    /// otherwise the main notch.
    func reading(on screen: NSScreen) -> Reading? {
        guard let reading, let id = screen.displayID else { return nil }
        return reading.display == id ? reading : nil
    }

    private static var screenUnderPointer: NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }

    private static func notchDisplay(for display: CGDirectDisplayID?) -> CGDirectDisplayID? {
        let notched = NotchCoordinator.screens(all: NotchSettings.showsOnAllScreens).compactMap(\.displayID)
        if let display, notched.contains(display) { return display }
        return notched.first
    }
}
