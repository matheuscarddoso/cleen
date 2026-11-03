import Foundation
import Synchronization
import Testing
@testable import CleenKit

struct NowPlayingTrackTests {
    @Test func theAppsFlagDecidesNotTheRate() throws {
        // A paused browser tab: the info still says rate 1.
        let paused = try #require(NowPlayingTrack(json: ["title": "Video", "playing": false, "rate": 1.0, "pid": 42]))
        #expect(!paused.isPlaying)
        let playing = try #require(NowPlayingTrack(json: ["title": "Song", "playing": true, "rate": 0.0, "pid": 42]))
        #expect(playing.isPlaying)
    }

    @Test func noTitleMeansNothingPlaying() {
        #expect(NowPlayingTrack(json: ["pid": 42, "playing": true]) == nil)
        #expect(NowPlayingTrack(json: ["title": "", "pid": 42, "playing": true]) == nil)
    }

    @Test func readsEveryField() throws {
        let track = try #require(NowPlayingTrack(json: [
            "title": "Clair de Lune", "artist": "Debussy", "album": "Suite", "duration": 300.0, "elapsed": 12.0,
            "timestamp": 1_000.0, "playing": true, "rate": 1.0, "pid": 7, "artworkKey": "abc",
        ]))
        #expect(track.artist == "Debussy" && track.album == "Suite" && track.pid == 7 && track.artworkKey == "abc")
        #expect(track.timestamp == Date(timeIntervalSince1970: 1_000))
        #expect(track.identity == "7|Clair de Lune|Debussy|Suite")
    }

    @Test func thePlayheadMovesAtTheRateOnlyWhilePlaying() {
        let start = Date(timeIntervalSince1970: 0)
        let fast = NowPlayingTrack(title: "Podcast", duration: 100, elapsed: 10, timestamp: start, isPlaying: true, rate: 1.5, pid: 1)
        #expect(fast.position(at: start.addingTimeInterval(10)) == 25)
        #expect(fast.position(at: start.addingTimeInterval(1_000)) == 100)
        let paused = NowPlayingTrack(title: "Podcast", elapsed: 10, timestamp: start, isPlaying: false, pid: 1)
        #expect(paused.position(at: start.addingTimeInterval(10)) == 10)
    }

    @Test func stoppingFreezesThePlayheadWhereItIs() {
        let start = Date(timeIntervalSince1970: 0)
        let track = NowPlayingTrack(title: "Song", duration: 200, elapsed: 10, timestamp: start, isPlaying: true, pid: 1)
        let stopped = track.playing(false, at: start.addingTimeInterval(5))
        #expect(!stopped.isPlaying)
        #expect(stopped.position(at: start.addingTimeInterval(60)) == 15)
        #expect(stopped.identity == track.identity)
        #expect(track.playing(true, at: start.addingTimeInterval(5)) == track)
    }
}

struct NowPlayingAudioTests {
    private func process(_ pid: Int32, _ bundleID: String, running: Bool = true) -> AudioProcess {
        AudioProcess(pid: pid, bundleID: bundleID, isRunningOutput: running)
    }

    @Test func matchesTheAppItself() {
        #expect(NowPlayingAudio.matches(process(10, "com.spotify.client"), pid: 10, bundleID: "com.spotify.client"))
        #expect(NowPlayingAudio.matches(process(10, ""), pid: 10, bundleID: nil))
        #expect(!NowPlayingAudio.matches(process(11, "com.apple.Music"), pid: 10, bundleID: "com.spotify.client"))
    }

    @Test func matchesBrowserHelpers() {
        #expect(NowPlayingAudio.matches(process(20, "com.google.Chrome.helper"), pid: 10, bundleID: "com.google.Chrome"))
        // Arc's helpers spell the bundle ID in lowercase.
        #expect(NowPlayingAudio.matches(process(20, "company.thebrowser.browser.helper"), pid: 10, bundleID: "company.thebrowser.Browser"))
        #expect(NowPlayingAudio.matches(process(20, "com.apple.WebKit.GPU"), pid: 10, bundleID: "com.apple.Safari"))
        #expect(NowPlayingAudio.matches(process(20, "org.mozilla.plugincontainer"), pid: 10, bundleID: "org.mozilla.firefox"))
        // Dia's helpers carry Arc's bundle ID; they're Dia's children, which is what counts.
        let diaHelper = AudioProcess(pid: 20, parentPID: 10, bundleID: "company.thebrowser.browser.helper", isRunningOutput: true)
        #expect(NowPlayingAudio.matches(diaHelper, pid: 10, bundleID: "company.thebrowser.dia"))
        #expect(!NowPlayingAudio.matches(diaHelper, pid: 11, bundleID: "company.thebrowser.dia"))
        // A prefix only counts up to a dot.
        #expect(!NowPlayingAudio.matches(process(20, "com.google.ChromeBeta.helper"), pid: 10, bundleID: "com.google.Chrome"))
        #expect(!NowPlayingAudio.matches(process(20, "com.apple.WebKit.GPU"), pid: 10, bundleID: "com.google.Chrome"))
    }

    @Test func anotherAppsChildNeverCounts() {
        // Arc is the source, on a paused tab; Dia, whose helpers share Arc's bundle ID,
        // is the one playing.
        let arc: Int32 = 10, dia: Int32 = 11
        let diaHelper = AudioProcess(pid: 20, parentPID: dia, bundleID: "company.thebrowser.browser.helper", isRunningOutput: true)
        #expect(!NowPlayingAudio.matches(diaHelper, pid: arc, bundleID: "company.thebrowser.Browser"))
        let arcHelper = AudioProcess(pid: 21, parentPID: arc, bundleID: "company.thebrowser.browser.helper", isRunningOutput: false)
        #expect(NowPlayingAudio.isAudible(pid: arc, bundleID: "company.thebrowser.Browser", in: [diaHelper, arcHelper]) == false)
        #expect(NowPlayingAudio.isAudible(pid: dia, bundleID: "company.thebrowser.dia", in: [diaHelper, arcHelper]) == true)
        // An XPC service, whose parent is launchd, is still tied by its bundle ID.
        let gpu = AudioProcess(pid: 30, parentPID: 1, bundleID: "com.apple.WebKit.GPU", isRunningOutput: true)
        #expect(NowPlayingAudio.matches(gpu, pid: 40, bundleID: "com.apple.Safari"))
        // And a Chrome helper some other app started isn't Chrome's.
        let foreign = AudioProcess(pid: 31, parentPID: 50, bundleID: "com.google.Chrome.helper", isRunningOutput: true)
        #expect(!NowPlayingAudio.matches(foreign, pid: 40, bundleID: "com.google.Chrome"))
    }

    @Test func isAudibleWhenAnyOfTheAppsProcessesPlays() {
        let processes = [process(10, "com.google.Chrome", running: false), process(20, "com.google.Chrome.helper"), process(30, "com.spotify.client", running: false)]
        #expect(NowPlayingAudio.isAudible(pid: 10, bundleID: "com.google.Chrome", in: processes) == true)
        #expect(NowPlayingAudio.isAudible(pid: 30, bundleID: "com.spotify.client", in: processes) == false)
    }

    @Test func cantTellForAnAppWithNoAudioClient() {
        let processes = [process(30, "com.spotify.client")]
        #expect(NowPlayingAudio.isAudible(pid: 40, bundleID: "com.example.Player", in: processes) == nil)
        // A browser with no helper in the list is making no sound.
        #expect(NowPlayingAudio.isAudible(pid: 10, bundleID: "com.google.Chrome", in: processes) == false)
        #expect(NowPlayingAudio.playsThroughHelpers("com.apple.Safari"))
        #expect(!NowPlayingAudio.playsThroughHelpers("com.spotify.client"))
    }
}

struct AudioProcessMonitorTests {
    @Test func reportsTheProcessListRightAway() async {
        let monitor = AudioProcessMonitor()
        let first = Mutex<[AudioProcess]?>(nil)
        monitor.start { processes in first.withLock { if $0 == nil { $0 = processes } } }
        // Up to two seconds, without hanging the suite if Core Audio never answers.
        for _ in 0..<40 where first.withLock({ $0 }) == nil {
            try? await Task.sleep(for: .milliseconds(50))
        }
        monitor.stop()
        let received = first.withLock { $0 }
        #expect(received != nil)
        // This test process isn't playing anything.
        let own = ProcessInfo.processInfo.processIdentifier
        #expect(received?.contains { $0.pid == own && $0.isRunningOutput } != true)
    }
}

struct PlaybackJudgeTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    @Test func aPausedAppIsNeverPlaying() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: false, at: start)
        judge.hear(true, throughHelpers: false, at: start)
        #expect(!judge.verdict(at: start).isPlaying)
    }

    @Test func theClaimStandsWhenCoreAudioCantTell() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(nil, throughHelpers: false, at: start)
        #expect(judge.verdict(at: at(60)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func aSilentBrowserStopsPlayingAfterTheGrace() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: true, at: start)
        #expect(judge.verdict(at: at(1)) == .init(isPlaying: true, recheckAt: at(judge.grace)))
        #expect(!judge.verdict(at: at(judge.grace)).isPlaying)
    }

    @Test func soundKeepsItPlaying() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: true, at: at(0.3))
        #expect(judge.verdict(at: at(30)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func goingQuietStartsTheGraceThen() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: false, at: start)
        judge.hear(false, throughHelpers: false, at: at(30))
        #expect(judge.verdict(at: at(31)).isPlaying)
        #expect(!judge.verdict(at: at(30 + judge.grace)).isPlaying)
        judge.hear(true, throughHelpers: false, at: at(40))
        #expect(judge.verdict(at: at(40)).isPlaying)
    }

    @Test func silenceFromAnAppNeverHeardDoesntCount() {
        // It may play through a daemon Cleen can't tie to it.
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: false, at: start)
        #expect(judge.verdict(at: at(60)).isPlaying)
    }

    @Test func aNewItemGetsAFreshGrace() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: true, at: start)
        judge.hear(false, throughHelpers: true, at: at(100))
        judge.report(source: 1, item: "b", isPlaying: true, at: at(101))
        #expect(judge.verdict(at: at(102)) == .init(isPlaying: true, recheckAt: at(101 + judge.grace)))
        // A heartbeat for the same item doesn't extend it.
        judge.report(source: 1, item: "b", isPlaying: true, at: at(102))
        #expect(!judge.verdict(at: at(101 + judge.grace)).isPlaying)
    }

    @Test func anotherSourceStartsOver() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: true, at: start)
        #expect(!judge.verdict(at: at(10)).isPlaying)
        judge.report(source: 2, item: "b", isPlaying: true, at: at(10))
        judge.hear(nil, throughHelpers: false, at: at(10))
        #expect(judge.verdict(at: at(10)).isPlaying)
    }

    @Test func theButtonsGuessShowsAtOnceAndRunsOut() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.expectToggle(from: true, at: start)
        #expect(judge.verdict(at: at(0.1)) == .init(isPlaying: false, recheckAt: at(judge.pauseWindow)))
        #expect(!judge.verdict(at: at(0.1)).isSettled)
        // A heartbeat that still says playing doesn't cancel it…
        judge.report(source: 1, item: "a", isPlaying: true, at: at(0.5))
        #expect(!judge.verdict(at: at(0.6)).isPlaying)
        // …but if nothing confirms it, the real state comes back.
        #expect(judge.verdict(at: at(judge.pauseWindow)).isPlaying)
    }

    @Test func silenceAfterPausingConfirmsItForGood() {
        // A browser that leaves its flag at playing: the pause shows at once and never
        // bounces back, not even for the grace after the sound stops.
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: true, at: start)
        judge.expectToggle(from: true, at: at(10))
        judge.hear(false, throughHelpers: true, at: at(10.1))
        judge.report(source: 1, item: "a", isPlaying: true, at: at(11))
        for t in stride(from: 10.0, through: 30, by: 0.05) {
            #expect(!judge.verdict(at: at(t)).isPlaying, "playing again at +\(t) s")
        }
        #expect(judge.verdict(at: at(12)) == .init(isPlaying: false, recheckAt: nil))
        // Sound again (played from the page itself) brings it back.
        judge.hear(true, throughHelpers: true, at: at(40))
        #expect(judge.verdict(at: at(40)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func pausingWhileAlreadyQuietSettlesAtOnce() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: true, at: start)
        judge.hear(false, throughHelpers: true, at: at(5))
        // Inside the grace, so the button still shows pause.
        #expect(judge.verdict(at: at(5.5)).isPlaying)
        judge.expectToggle(from: true, at: at(5.5))
        #expect(judge.verdict(at: at(5.5)) == .init(isPlaying: false, recheckAt: nil))
        #expect(!judge.verdict(at: at(60)).isPlaying)
    }

    @Test func silenceThatStartsAfterThePauseWindowStillGetsTheGrace() {
        // The command may have gone elsewhere; silence long after it is ordinary silence.
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(true, throughHelpers: true, at: start)
        judge.expectToggle(from: true, at: at(10))
        judge.hear(false, throughHelpers: true, at: at(10 + judge.pauseWindow + 1))
        #expect(judge.verdict(at: at(10 + judge.pauseWindow + 1.1)).isPlaying)
    }

    @Test func pressingPlayOnAStaleClaimWaitsForSound() {
        // A tab whose flag stayed at playing, judged silent: the button shows play.
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: true, at: start)
        #expect(!judge.verdict(at: at(60)).isPlaying)
        judge.expectToggle(from: false, at: at(60))
        // The heartbeat repeats the stale claim; that confirms nothing, and the guess and
        // then a fresh grace hold the state while the page starts.
        judge.report(source: 1, item: "a", isPlaying: true, at: at(60.2))
        #expect(judge.verdict(at: at(60.2)).isPlaying)
        #expect(judge.verdict(at: at(60 + judge.playWindow)) == .init(isPlaying: true, recheckAt: at(60 + judge.grace)))
        judge.hear(true, throughHelpers: true, at: at(61.6))
        #expect(judge.verdict(at: at(61.6)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func pressingPlayThatNothingAnswersFallsBack() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: true, at: start)
        judge.expectToggle(from: false, at: at(60))
        judge.report(source: 1, item: "a", isPlaying: true, at: at(60.2))
        #expect(!judge.verdict(at: at(60 + max(judge.playWindow, judge.grace))).isPlaying)
    }

    @Test func aClaimStillInItsGraceIsntSettled() {
        // A new item that claims to play but makes no sound yet isn't news.
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.hear(false, throughHelpers: true, at: start)
        #expect(judge.verdict(at: at(0.5)).isPlaying)
        #expect(!judge.verdict(at: at(0.5)).isSettled)
        judge.hear(true, throughHelpers: true, at: at(3))
        #expect(judge.verdict(at: at(3)).isSettled)
        // Spotify heard playing, on to the next song: settled from the start.
        var spotify = PlaybackJudge()
        spotify.report(source: 2, item: "a", isPlaying: true, at: start)
        spotify.hear(true, throughHelpers: false, at: start)
        spotify.report(source: 2, item: "b", isPlaying: true, at: at(200))
        #expect(spotify.verdict(at: at(200)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func aConfirmingReadingSettlesTheGuess() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: false, at: start)
        judge.expectToggle(from: false, at: start)
        judge.report(source: 1, item: "a", isPlaying: true, at: at(0.3))
        judge.hear(true, throughHelpers: false, at: at(0.4))
        #expect(judge.verdict(at: at(10)) == .init(isPlaying: true, recheckAt: nil))
    }

    @Test func resetForgetsTheGuess() {
        var judge = PlaybackJudge()
        judge.report(source: 1, item: "a", isPlaying: true, at: start)
        judge.expectToggle(from: true, at: start)
        judge.reset()
        #expect(judge.verdict(at: at(0.1)) == .init(isPlaying: false, recheckAt: nil))
    }
}
