import AppKit
import CleenKit
import Foundation
import Observation
import UserNotifications

/// The running timer, shared by the tab, the widget and the closed notch.
///
/// Nothing ticks here: the model only holds dates (`TimerSession`), and views render
/// the countdown with `TimerTicks` (a `TimelineView`). One sleeping task wakes up when
/// the phase ends to notify, play a sound and move Pomodoro along.
///
/// Read API for the closed notch's wing:
/// - `isActive`: something was started and not reset (running or paused).
/// - `isRunning`: the clock is moving; `endDate` is when the phase ends.
/// - `remaining(at:)`: seconds left at a date (the phase length while idle).
/// - `progress(at:)`: share of the phase gone by, 0 at the start, 1 at the end.
/// - `phaseTitle`: "Timer", "Foco" or "Pausa".
@Observable
final class TimerModel {
    /// The one-tap lengths, in minutes.
    static let presets = [5, 10, 15, 25, 45, 60]
    static let minuteRange = Int(TimerSession.minimumLength / 60)...Int(TimerSession.maximumLength / 60)

    private(set) var session: TimerSession

    /// Called on the main actor after a phase ends on its own, with the phase that
    /// ended (for example, to present the notch).
    @ObservationIgnored var onPhaseEnd: ((TimerPhase) -> Void)?

    @ObservationIgnored private var completion: Task<Void, Never>?
    @ObservationIgnored private var sound: NSSound?
    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let sessionKey = "timerSession"

    init() {
        var session = TimerModel.load() ?? TimerSession()
        session.settle(at: .now)
        self.session = session
        scheduleCompletion()
    }

    // MARK: Read API

    var isActive: Bool { session.isActive }
    var isRunning: Bool { session.isRunning }
    var isPaused: Bool { session.isPaused }
    var canReset: Bool { session.canReset }
    var endDate: Date? { session.endDate }
    var mode: TimerMode { session.mode }
    var phase: TimerPhase { session.phase }
    var round: Int { session.round }
    var plan: PomodoroPlan { session.plan }
    var rounds: Int { session.plan.rounds }

    func remaining(at date: Date) -> TimeInterval { session.remaining(at: date) }
    func progress(at date: Date) -> Double { session.progress(at: date) }

    var phaseTitle: String {
        switch session.phase {
        case .countdown: "Timer"
        case .focus: "Foco"
        case .shortBreak, .longBreak: "Pausa"
        }
    }

    /// "Foco · rodada 2 de 4", "Pausa longa", "Timer de 10 min".
    var phaseDetail: String {
        switch session.phase {
        case .countdown: "Timer de \(TimerClock.length(session.duration))"
        case .focus: "Foco · rodada \(session.round) de \(rounds)"
        case .shortBreak: "Pausa · rodada \(session.round) de \(rounds)"
        case .longBreak: "Pausa longa"
        }
    }

    /// The countdown length being picked, in whole minutes.
    var countdownMinutes: Int {
        get { Int((session.countdownLength / 60).rounded()) }
        set { change { $0.setCountdownLength(TimeInterval(newValue) * 60) } }
    }

    // MARK: Actions

    func toggle() {
        if !session.isActive { Self.askForNotifications() }
        change { $0.toggle(at: .now) }
    }

    func reset() { change { $0.reset() } }
    func addMinute() { change { $0.addMinute(at: .now) } }
    func skip() { change { $0.skip(at: .now) } }

    func setMode(_ mode: TimerMode) { change { $0.setMode(mode) } }

    // MARK: Internals

    private func change(_ body: (inout TimerSession) -> Void) {
        var next = session
        body(&next)
        guard next != session else { return }
        session = next
        persist()
        scheduleCompletion()
    }

    /// One wake-up for the end of the phase. `Task.sleep` runs on the continuous clock,
    /// which keeps counting while the Mac sleeps, and the loop re-checks the wall clock
    /// in case it moved.
    private func scheduleCompletion() {
        completion?.cancel()
        guard let end = session.endDate else { return }
        completion = Task { [weak self] in
            while !Task.isCancelled {
                let left = end.timeIntervalSinceNow
                if left <= 0 { break }
                try? await Task.sleep(for: .seconds(left), tolerance: .milliseconds(50))
            }
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    private func complete() {
        guard session.isFinished(at: .now) else { return }
        let length = session.duration
        var next = session
        let ended = next.finishPhase(at: .now)
        session = next
        persist()
        scheduleCompletion()

        playSound()
        let (title, body) = announcement(ended: ended, length: length)
        Task { await Self.post(title: title, body: body) }
        onPhaseEnd?(ended)
    }

    private func announcement(ended: TimerPhase, length: TimeInterval) -> (String, String) {
        let next = TimerClock.length(session.duration)
        switch ended {
        case .countdown: return ("Timer concluído", "O timer de \(TimerClock.length(length)) terminou.")
        case .focus where session.phase == .longBreak:
            return ("Ciclo concluído", "\(rounds) rodadas de foco. Pausa longa de \(next).")
        case .focus: return ("Foco concluído", "Pausa de \(next) começou.")
        case .shortBreak, .longBreak: return ("Pausa concluída", "Hora de focar: rodada \(session.round) de \(rounds).")
        }
    }

    private func playSound() {
        sound?.stop()
        sound = NSSound(named: "Glass")
        sound?.play()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: Self.sessionKey)
    }

    private static func load() -> TimerSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(TimerSession.self, from: data)
    }

    /// Asked the first time a timer starts, the moment the reason is obvious.
    private static func askForNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Silent: the sound is played by the app, so it doesn't ring twice.
    private static func post(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: "timer", content: content, trigger: nil)
        try? await center.add(request)
    }
}
