import AppKit
import CleenKit
import Foundation
import Observation

/// The teleprompter's script and pace. The script saves itself a moment after the last
/// keystroke, off the main thread, the same way Notas does; pace and size live in
/// UserDefaults.
@Observable
final class TeleprompterModel {
    enum Phase: Equatable {
        case editing
        /// 3, 2, 1 before the text starts moving.
        case countdown(Int)
        case playing
        case paused
        case finished
    }

    private(set) var phase = Phase.editing
    private(set) var clock = TeleprompterClock()
    private(set) var words = 0

    var script = "" {
        didSet {
            guard script != oldValue else { return }
            words = TeleprompterPace.wordCount(script)
            changed()
        }
    }

    var wordsPerMinute: Int {
        didSet {
            // Assigning inside didSet doesn't call it again.
            wordsPerMinute = TeleprompterPace.clamped(wordsPerMinute)
            guard wordsPerMinute != oldValue else { return }
            UserDefaults.standard.set(wordsPerMinute, forKey: Self.paceKey)
            retime()
        }
    }

    var fontSize: Double {
        didSet {
            fontSize = TeleprompterPace.clampedFont(fontSize)
            guard fontSize != oldValue else { return }
            UserDefaults.standard.set(fontSize, forKey: Self.fontKey)
        }
    }

    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var finishTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var editedBeforeLoad = false
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    private static let paceKey = "teleprompter.wordsPerMinute"
    private static let fontKey = "teleprompter.fontSize"
    private nonisolated static let folder = URL.applicationSupportDirectory.appending(path: "Cleen", directoryHint: .isDirectory)
    private nonisolated static let file = folder.appending(path: "teleprompter.txt")
    /// One write at a time, in order: a slow older write can't land over a newer one.
    private nonisolated static let writer = DispatchQueue(label: "app.cleen.teleprompter-writer", qos: .utility)
    private static let saveDelay = Duration.milliseconds(600)

    init() {
        let defaults = UserDefaults.standard
        let pace = defaults.integer(forKey: Self.paceKey)
        wordsPerMinute = pace == 0 ? TeleprompterPace.normal : TeleprompterPace.clamped(pace)
        let size = defaults.double(forKey: Self.fontKey)
        fontSize = size == 0 ? TeleprompterPace.defaultFontSize : TeleprompterPace.clampedFont(size)
        Task { await load() }
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    var canStart: Bool { words > 0 }
    var isPresenting: Bool { phase != .editing }
    var isRunning: Bool { phase == .playing }

    /// Seconds the whole script takes at the current pace.
    var readingTime: TimeInterval {
        TeleprompterPace.readingTime(words: words, wordsPerMinute: wordsPerMinute)
    }

    func progress(at date: Date) -> Double {
        clock.progress(at: date.timeIntervalSinceReferenceDate)
    }

    // MARK: Playback

    /// From the editor: a 3-2-1, then the text starts moving from the top.
    func start() {
        guard canStart else { return }
        cancelTimers()
        clock = TeleprompterClock(rate: rate)
        runCountdown()
    }

    func togglePause() {
        switch phase {
        case .playing: pause()
        case .paused: resume()
        case .finished: restart()
        case .editing, .countdown: break
        }
    }

    func pause() {
        guard phase == .playing else { return }
        clock.pause(at: now)
        finishTask?.cancel()
        phase = .paused
    }

    /// Picks up where it stopped, straight away: a countdown there would only get in the way.
    func resume() {
        guard phase == .paused else { return }
        clock.start(at: now)
        phase = .playing
        scheduleFinish()
    }

    func restart() {
        guard phase != .editing else { return }
        cancelTimers()
        clock.reset()
        runCountdown()
    }

    func stop() {
        cancelTimers()
        clock.reset()
        phase = .editing
    }

    /// ↑ ↓ and the side buttons: one notch on the 10-word grid.
    func nudgePace(by steps: Int) {
        wordsPerMinute = TeleprompterPace.stepped(wordsPerMinute, by: steps)
    }

    private var now: TimeInterval { Date.now.timeIntervalSinceReferenceDate }

    private var rate: Double {
        TeleprompterPace.progressPerSecond(words: words, wordsPerMinute: wordsPerMinute)
    }

    private func runCountdown() {
        phase = .countdown(3)
        countdownTask = Task { [weak self] in
            for value in [2, 1] {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                self?.phase = .countdown(value)
            }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled, let self else { return }
            self.clock.start(at: self.now)
            self.phase = .playing
            self.scheduleFinish()
        }
    }

    private func retime() {
        clock.setRate(rate, at: now)
        if phase == .playing { scheduleFinish() }
    }

    /// The clock already stops at the last line; this just flips the controls over to
    /// "again" at the moment it gets there.
    private func scheduleFinish() {
        finishTask?.cancel()
        guard let remaining = clock.remaining(at: now) else { return }
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled, let self, self.phase == .playing else { return }
            self.clock.pause(at: self.now)
            self.phase = .finished
        }
    }

    private func cancelTimers() {
        countdownTask?.cancel()
        countdownTask = nil
        finishTask?.cancel()
        finishTask = nil
    }

    // MARK: Saving

    private func changed() {
        if !isLoaded { editedBeforeLoad = true }
        scheduleSave()
    }

    private func load() async {
        let file = Self.file
        let saved = await offMain { () -> String? in
            try? String(contentsOf: file, encoding: .utf8)
        }
        isLoaded = true
        // Typing that beat the read wins: it's newer than the file.
        if editedBeforeLoad {
            scheduleSave()
        } else if let saved {
            script = saved
            saveTask?.cancel()
        }
    }

    private func scheduleSave() {
        // Never write before the file was read: that would replace it with a blank script.
        guard isLoaded else { return }
        saveTask?.cancel()
        let script = script
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Self.writer.async { @Sendable in
                    Self.write(script)
                    continuation.resume()
                }
            }
            if !Task.isCancelled { self.saveTask = nil }
        }
    }

    private func flush() {
        guard let saveTask else { return }
        saveTask.cancel()
        self.saveTask = nil
        let script = script
        Self.writer.sync { Self.write(script) }
    }

    private nonisolated static func write(_ script: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data(script.utf8).write(to: file, options: .atomic)
    }
}
