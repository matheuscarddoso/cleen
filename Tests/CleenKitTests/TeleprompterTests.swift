import Foundation
import Testing
@testable import CleenKit

struct TeleprompterTests {
    @Test func countsSpokenWordsOnly() {
        #expect(TeleprompterPace.wordCount("") == 0)
        #expect(TeleprompterPace.wordCount("  \n\t ") == 0)
        #expect(TeleprompterPace.wordCount("Olá, mundo!") == 2)
        #expect(TeleprompterPace.wordCount("Ação — é agora.\n\nSegundo parágrafo") == 5)
        #expect(TeleprompterPace.wordCount("São 3 pontos: um, dois e três.") == 7)
    }

    @Test func readingTimeFollowsThePace() {
        #expect(TeleprompterPace.readingTime(words: 140, wordsPerMinute: 140) == 60)
        #expect(TeleprompterPace.readingTime(words: 70, wordsPerMinute: 140) == 30)
        #expect(TeleprompterPace.readingTime(words: 0, wordsPerMinute: 140) == 0)
        // Out-of-range paces are clamped, never divide by zero.
        #expect(TeleprompterPace.readingTime(words: 60, wordsPerMinute: 0) == 60)
        #expect(TeleprompterPace.progressPerSecond(words: 0, wordsPerMinute: 140) == 0)
        #expect(TeleprompterPace.progressPerSecond(words: 140, wordsPerMinute: 140) == 1.0 / 60)
    }

    @Test func steppingSnapsToTheGridAndStaysInRange() {
        #expect(TeleprompterPace.stepped(140, by: 1) == 150)
        #expect(TeleprompterPace.stepped(140, by: -1) == 130)
        #expect(TeleprompterPace.stepped(145, by: 1) == 150)
        #expect(TeleprompterPace.stepped(145, by: -1) == 140)
        #expect(TeleprompterPace.stepped(260, by: 1) == 260)
        #expect(TeleprompterPace.stepped(60, by: -1) == 60)
        #expect(TeleprompterPace.clamped(500) == 260)
        #expect(TeleprompterPace.clampedFont(40) == 28)
        #expect(TeleprompterPace.clampedFont(10) == 20)
    }

    @Test func clockAdvancesOnlyWhileRunning() {
        var clock = TeleprompterClock(rate: 0.1)
        #expect(clock.progress(at: 5) == 0)
        clock.start(at: 10)
        #expect(abs(clock.progress(at: 12) - 0.2) < 1e-9)
        clock.pause(at: 13)
        #expect(abs(clock.progress(at: 100) - 0.3) < 1e-9)
        #expect(clock.remaining(at: 100) == nil)
        clock.start(at: 200)
        #expect(abs(clock.progress(at: 201) - 0.4) < 1e-9)
        #expect(abs((clock.remaining(at: 201) ?? 0) - 6) < 1e-9)
    }

    @Test func changingThePaceDoesNotJump() {
        var clock = TeleprompterClock(rate: 0.1)
        clock.start(at: 0)
        clock.setRate(0.2, at: 2)
        #expect(abs(clock.progress(at: 2) - 0.2) < 1e-9)
        #expect(abs(clock.progress(at: 3) - 0.4) < 1e-9)
    }

    @Test func clockStopsAtTheEndAndResets() {
        var clock = TeleprompterClock(rate: 0.5)
        clock.start(at: 0)
        #expect(clock.progress(at: 10) == 1)
        #expect(clock.isFinished(at: 10))
        clock.reset()
        #expect(clock.progress(at: 10) == 0)
        #expect(!clock.isRunning)
    }
}
