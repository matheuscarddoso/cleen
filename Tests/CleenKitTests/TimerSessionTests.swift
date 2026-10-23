import Foundation
import Testing
@testable import CleenKit

struct TimerSessionTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func idleShowsThePickedLength() {
        let session = TimerSession(countdownLength: 15 * 60)
        #expect(!session.isActive)
        #expect(session.remaining(at: t0) == 15 * 60)
        #expect(session.progress(at: t0) == 0)
    }

    @Test func startPauseResumeKeepsTheRemainingTime() {
        var session = TimerSession(countdownLength: 10 * 60)
        session.start(at: t0)
        #expect(session.isRunning)
        #expect(session.endDate == t0.addingTimeInterval(600))

        session.pause(at: t0.addingTimeInterval(100))
        #expect(session.isPaused && !session.isRunning)
        #expect(session.remaining(at: t0.addingTimeInterval(5_000)) == 500)

        session.toggle(at: t0.addingTimeInterval(1_000))
        #expect(session.endDate == t0.addingTimeInterval(1_500))
        #expect(session.progress(at: t0.addingTimeInterval(1_350)) == 0.75)
    }

    @Test func addMinuteExtendsEveryState() {
        var idle = TimerSession(countdownLength: 5 * 60)
        idle.addMinute(at: t0)
        #expect(idle.remaining(at: t0) == 6 * 60)
        #expect(idle.countdownLength == 6 * 60)

        var running = TimerSession(countdownLength: 5 * 60)
        running.start(at: t0)
        running.addMinute(at: t0.addingTimeInterval(60))
        #expect(running.remaining(at: t0.addingTimeInterval(60)) == 300)
        #expect(running.duration == 360)
        // The picked length stays what the person chose.
        #expect(running.countdownLength == 300)

        var paused = running
        paused.pause(at: t0.addingTimeInterval(60))
        paused.addMinute(at: t0)
        #expect(paused.remaining(at: t0) == 360)
    }

    @Test func countdownFinishesBackToIdle() {
        var session = TimerSession(countdownLength: 5 * 60)
        session.start(at: t0)
        #expect(!session.isFinished(at: t0.addingTimeInterval(299)))
        #expect(session.isFinished(at: t0.addingTimeInterval(300)))
        #expect(session.remaining(at: t0.addingTimeInterval(400)) == 0)

        let ended = session.finishPhase(at: t0.addingTimeInterval(300))
        #expect(ended == .countdown)
        #expect(!session.isActive)
        #expect(session.remaining(at: t0) == 300)
    }

    @Test func lengthIsClampedAndLockedWhileRunning() {
        var session = TimerSession(countdownLength: 10)
        #expect(session.countdownLength == TimerSession.minimumLength)
        session.setCountdownLength(10_000 * 60)
        #expect(session.countdownLength == TimerSession.maximumLength)

        session.setCountdownLength(20 * 60)
        session.start(at: t0)
        session.setCountdownLength(30 * 60)
        #expect(session.duration == 20 * 60)
    }

    @Test func pomodoroRunsFourRoundsThenALongBreak() {
        var session = TimerSession()
        session.setMode(.pomodoro)
        #expect(session.phase == .focus && session.round == 1)
        #expect(session.duration == 25 * 60)

        var now = t0
        session.start(at: now)
        var sequence: [(TimerPhase, Int)] = []
        for _ in 0..<8 {
            now = session.endDate!
            session.finishPhase(at: now)
            #expect(session.isRunning)
            sequence.append((session.phase, session.round))
        }
        #expect(sequence.map(\.0) == [.shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak, .focus])
        #expect(sequence.map(\.1) == [1, 2, 2, 3, 3, 4, 4, 1])
        #expect(session.endDate == now.addingTimeInterval(25 * 60))
    }

    @Test func skipKeepsTheRunningState() {
        var idle = TimerSession()
        idle.setMode(.pomodoro)
        idle.skip(at: t0)
        #expect(idle.phase == .shortBreak && !idle.isRunning)

        var running = TimerSession()
        running.setMode(.pomodoro)
        running.start(at: t0)
        running.skip(at: t0.addingTimeInterval(10))
        #expect(running.phase == .shortBreak)
        #expect(running.endDate == t0.addingTimeInterval(10 + 5 * 60))
    }

    @Test func settleAfterRelaunchWaitsForThePerson() {
        var session = TimerSession()
        session.setMode(.pomodoro)
        session.start(at: t0)
        session.settle(at: t0.addingTimeInterval(60))
        #expect(session.isRunning)

        session.settle(at: t0.addingTimeInterval(3_600))
        #expect(session.phase == .shortBreak)
        #expect(!session.isActive)
    }

    @Test func resetIsOfferedOnlyWhenItChangesSomething() {
        var session = TimerSession()
        #expect(!session.canReset)
        session.setMode(.pomodoro)
        #expect(!session.canReset)
        session.skip(at: t0)
        #expect(session.canReset)
        session.reset()
        #expect(!session.canReset && session.phase == .focus)
    }

    @Test func survivesARoundTripThroughJSON() throws {
        var session = TimerSession(countdownLength: 45 * 60)
        session.start(at: t0)
        let data = try JSONEncoder().encode(session)
        #expect(try JSONDecoder().decode(TimerSession.self, from: data) == session)
    }

    @Test func modeSwitchResets() {
        var session = TimerSession(countdownLength: 15 * 60)
        session.start(at: t0)
        session.setMode(.pomodoro)
        #expect(!session.isActive && session.duration == 25 * 60)
        session.setMode(.countdown)
        #expect(session.duration == 15 * 60 && session.phase == .countdown)
    }

    @Test(arguments: [
        (1500.0, "25:00"), (0.2, "0:01"), (0, "0:00"), (59.01, "1:00"),
        (5999, "99:59"), (6000, "1:40:00"), (10_800, "3:00:00"), (-4, "0:00")
    ])
    func clockText(seconds: TimeInterval, text: String) {
        #expect(TimerClock.string(seconds) == text)
    }

    @Test(arguments: [(300.0, "5 min"), (3600, "1h"), (5400, "1h 30min")])
    func lengthText(seconds: TimeInterval, text: String) {
        #expect(TimerClock.length(seconds) == text)
    }
}
