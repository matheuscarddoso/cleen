import AppKit
import AVFoundation
import CoreAudio
import Observation
import os

/// A call or meeting going on, found the way macOS knows who's using the microphone:
/// Core Audio lists, process by process, which ones are taking input. A known calling app
/// (Zoom, Teams, FaceTime, WhatsApp…), a browser (Google Meet and the like) or the iPhone's
/// call relayed to the Mac means a call; dictation or a voice memo doesn't.
@Observable
final class CallMonitor {
    struct Call: Equatable {
        let app: CallApp
        let pid: pid_t
        let since: Date
    }

    private(set) var call: Call?
    /// Recent voice levels, 0…1, newest last (the closed notch's bars).
    private(set) var levels: [Double] = Array(repeating: 0, count: CallMonitor.barCount)
    private(set) var isMicMuted = false
    /// What Cleen last asked the app for (the apps don't say).
    var isCameraOff = false
    var isSharingOff = true

    static let barCount = 14

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private let meter = CallVoiceMeter()
    @ObservationIgnored var isCleenUsingMicrophone: () -> Bool = { false }
    private static let log = Logger(subsystem: "app.cleen.Cleen", category: "calls")

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.check()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func check() {
        let found = Self.callingProcess()
        if let found, !(found.pid == ProcessInfo.processInfo.processIdentifier) {
            if call?.pid != found.pid {
                call = Call(app: found.app, pid: found.pid, since: .now)
                isCameraOff = false
                isSharingOff = true
                Self.log.notice("call started in \(found.app.name, privacy: .public)")
                startMeter()
            }
            isMicMuted = MicrophoneMute.isMuted
        } else if call != nil {
            call = nil
            meter.stop()
            levels = Array(repeating: 0, count: Self.barCount)
        }
    }

    private func startMeter() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        meter.start { [weak self] level in
            guard let self else { return }
            var next = self.levels
            next.removeFirst()
            next.append(self.isMicMuted ? 0 : level)
            self.levels = next
        }
    }

    /// A call in Zoom with a talking voice, for checking the look (`--live call`).
    func preview() {
        loop?.cancel()
        call = Call(app: .zoom, pid: ProcessInfo.processInfo.processIdentifier, since: .now.addingTimeInterval(-6))
        Task {
            for step in 0..<200 {
                var next = levels
                next.removeFirst()
                next.append(0.25 + 0.6 * abs(sin(Double(step) * 0.7)) * Double.random(in: 0.5...1))
                levels = next
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
    }

    // MARK: Controls

    func toggleMicrophone() {
        if MicrophoneMute.canMute {
            MicrophoneMute.set(!isMicMuted)
            isMicMuted = MicrophoneMute.isMuted
        } else if let call, let shortcut = call.app.shortcuts.microphone {
            shortcut.send(to: call.pid)
            isMicMuted.toggle()
        }
    }

    func toggleCamera() {
        guard let call, let shortcut = call.app.shortcuts.camera else { return }
        shortcut.send(to: call.pid)
        isCameraOff.toggle()
    }

    func toggleSharing() {
        guard let call, let shortcut = call.app.shortcuts.share else { return }
        shortcut.send(to: call.pid)
        isSharingOff.toggle()
    }

    /// Leaves the call (the app may ask to confirm); where the app has no shortcut for
    /// it, brings the app forward.
    func hangUp() {
        guard let call else { return }
        if let shortcut = call.app.shortcuts.hangUp {
            shortcut.send(to: call.pid)
        } else {
            NSRunningApplication(processIdentifier: call.pid)?.activate()
        }
    }

    func showApp() {
        guard let call else { return }
        NSRunningApplication(processIdentifier: call.pid)?.activate()
    }

    // MARK: Who's using the microphone

    private static func callingProcess() -> (app: CallApp, pid: pid_t)? {
        let own = ProcessInfo.processInfo.processIdentifier
        for process in audioProcesses() where process.isRunningInput && process.pid != own {
            if let app = CallApp(bundleID: process.bundleID) { return (app, process.pid) }
        }
        return nil
    }

    private struct AudioProcess {
        let pid: pid_t
        let bundleID: String
        let isRunningInput: Bool
    }

    private static func audioProcesses() -> [AudioProcess] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr else { return [] }
        return objects.compactMap { object in
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningInput, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(object, &runningAddress, 0, nil, &runningSize, &running) == noErr else { return nil }
            var pid: pid_t = 0
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyData(object, &pidAddress, 0, nil, &pidSize, &pid)
            var bundle: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            var bundleAddress = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectGetPropertyData(object, &bundleAddress, 0, nil, &bundleSize, &bundle)
            let id = bundle?.takeRetainedValue() as String? ?? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
            return AudioProcess(pid: pid, bundleID: id, isRunningInput: running != 0)
        }
    }
}

/// The apps a call can be in, with the shortcuts they have for its controls.
enum CallApp: Equatable {
    case zoom, teams, meet(browser: String), faceTime, iPhone, whatsApp, telegram, slack, discord

    init?(bundleID: String) {
        switch bundleID {
        case "us.zoom.xos": self = .zoom
        case "com.microsoft.teams2", "com.microsoft.teams": self = .teams
        case "com.apple.FaceTime", "com.apple.avconferenced": self = .faceTime
        case "com.apple.telephonyutilities.callservicesd", "com.apple.TelephonyUtilities": self = .iPhone
        case "net.whatsapp.WhatsApp", "desktop.WhatsApp": self = .whatsApp
        case "ru.keepcoder.Telegram", "org.telegram.desktop": self = .telegram
        case "com.tinyspeck.slackmacgap": self = .slack
        case "com.hnc.Discord": self = .discord
        case "com.google.Chrome", "company.thebrowser.Browser", "company.thebrowser.dia", "com.apple.Safari", "org.mozilla.firefox",
             "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera":
            self = .meet(browser: bundleID)
        default: return nil
        }
    }

    var name: String {
        switch self {
        case .zoom: "Zoom"
        case .teams: "Teams"
        case .meet: "Google Meet"
        case .faceTime: "FaceTime"
        case .iPhone: String(localized: "iPhone")
        case .whatsApp: "WhatsApp"
        case .telegram: "Telegram"
        case .slack: "Slack"
        case .discord: "Discord"
        }
    }

    struct Shortcuts {
        var microphone: KeyShortcut?
        var camera: KeyShortcut?
        var share: KeyShortcut?
        var hangUp: KeyShortcut?
    }

    var shortcuts: Shortcuts {
        switch self {
        case .zoom:
            Shortcuts(microphone: KeyShortcut(key: 0, shift: true), camera: KeyShortcut(key: 9, shift: true), share: KeyShortcut(key: 1, shift: true), hangUp: KeyShortcut(key: 13, shift: false))
        case .teams:
            Shortcuts(microphone: KeyShortcut(key: 46, shift: true), camera: KeyShortcut(key: 31, shift: true), share: KeyShortcut(key: 14, shift: true), hangUp: KeyShortcut(key: 4, shift: true))
        case .meet:
            Shortcuts(microphone: KeyShortcut(key: 2, shift: false), camera: KeyShortcut(key: 14, shift: false))
        case .slack:
            Shortcuts(microphone: KeyShortcut(key: 49, shift: true), hangUp: KeyShortcut(key: 4, shift: true))
        case .discord:
            Shortcuts(microphone: KeyShortcut(key: 46, shift: true))
        case .faceTime, .iPhone, .whatsApp, .telegram:
            Shortcuts()
        }
    }
}

/// ⌘ (and ⇧) plus a key, sent straight to one app without bringing it forward.
struct KeyShortcut {
    /// The virtual key code (A is 0, W is 13…).
    let key: CGKeyCode
    let shift: Bool

    func send(to pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        var flags: CGEventFlags = .maskCommand
        if shift { flags.insert(.maskShift) }
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            event.postToPid(pid)
        }
    }
}

/// The default input's mute, for every app at once.
enum MicrophoneMute {
    private static var device: AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static var address: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    }

    static var canMute: Bool {
        guard let device else { return false }
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    static var isMuted: Bool {
        guard let device else { return false }
        var address = address
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    static func set(_ muted: Bool) {
        guard let device else { return }
        var address = address
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }
}

/// The voice's loudness, a few times a second, from the default input. Runs only
/// while a call is on.
nonisolated final class CallVoiceMeter: @unchecked Sendable {
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private var peak: Float = 0
    private var timer: Task<Void, Never>?

    @MainActor
    func start(_ report: @escaping @MainActor (Double) -> Void) {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData?[0] else { return }
            var sum: Float = 0
            let count = Int(buffer.frameLength)
            for index in 0..<count { sum += data[index] * data[index] }
            let rms = sqrt(sum / Float(max(1, count)))
            self.lock.withLock { self.peak = max(self.peak, rms) }
        }
        do {
            try engine.start()
        } catch {
            return
        }
        self.engine = engine
        timer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(110))
                guard let self else { return }
                let level = self.lock.withLock {
                    defer { self.peak = 0 }
                    return self.peak
                }
                // A speaking voice sits around -30…-10 dB.
                let db = 20 * log10(max(level, 0.000_01))
                report(Double(min(1, max(0, (db + 50) / 40))))
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
