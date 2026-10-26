import Foundation
import Testing
@testable import CleenKit

struct MediaKeyTests {
    @Test func decodesTheVolumeUpKeyDown() throws {
        // What a MacBook keyboard sends for F12 pressed: NX_KEYTYPE_SOUND_UP, state 0x0A.
        let press = try #require(MediaKey.decode(subtype: 8, data1: 0x0000_0A00))
        #expect(press == MediaKey.Press(key: .volumeUp, isDown: true, isRepeat: false))
    }

    @Test func decodesReleaseAndRepeat() throws {
        let release = try #require(MediaKey.decode(subtype: 8, data1: 0x0003_0B00))
        #expect(release == MediaKey.Press(key: .brightnessDown, isDown: false, isRepeat: false))
        let held = try #require(MediaKey.decode(subtype: 8, data1: 0x0001_0A01))
        #expect(held == MediaKey.Press(key: .volumeDown, isDown: true, isRepeat: true))
    }

    @Test func roundTripsEveryKey() {
        for key in MediaKey.allCases {
            for isDown in [true, false] {
                let press = MediaKey.Press(key: key, isDown: isDown, isRepeat: isDown)
                #expect(MediaKey.decode(subtype: 8, data1: MediaKey.data1(for: press)) == press)
            }
        }
    }

    @Test func ignoresOtherKeysAndSubtypes() {
        // NX_KEYTYPE_PLAY (16) and the keyboard backlight (21) stay with macOS.
        #expect(MediaKey.decode(subtype: 8, data1: 16 << 16 | 0x0A00) == nil)
        #expect(MediaKey.decode(subtype: 8, data1: 21 << 16 | 0x0A00) == nil)
        // Subtype 7 is a mouse-button change, whose data1 means something else.
        #expect(MediaKey.decode(subtype: 7, data1: 0x0000_0A00) == nil)
        #expect(MediaKey.decode(subtype: 8, data1: 0x0000_0500) == nil)
    }

    @Test func stepsInSixteenthsAndSnapsToTheGrid() {
        #expect(LevelStep.next(0.5, up: true, fine: false) == 0.5625)
        #expect(LevelStep.next(0.5, up: false, fine: false) == 0.4375)
        // Off the grid (a slider put it there): the first press lands on a step.
        #expect(LevelStep.next(0.53, up: true, fine: false) == 0.5625)
        #expect(LevelStep.next(0.53, up: false, fine: false) == 0.5)
        // A hair under a step, as devices report it, still counts as that step.
        #expect(LevelStep.next(0.5624999, up: true, fine: false) == 0.625)
    }

    @Test func fineStepsAreAQuarter() {
        #expect(LevelStep.next(0.5, up: true, fine: true) == 0.515625)
        #expect(LevelStep.next(0.5, up: false, fine: true) == 0.484375)
    }

    @Test func clampsAtTheEnds() {
        #expect(LevelStep.next(1, up: true, fine: false) == 1)
        #expect(LevelStep.next(0.98, up: true, fine: false) == 1)
        #expect(LevelStep.next(0, up: false, fine: false) == 0)
        #expect(LevelStep.next(0.02, up: false, fine: false) == 0)
    }

    @Test func percentRounds() {
        #expect(LevelStep.percent(0.5625) == 56)
        #expect(LevelStep.percent(1.2) == 100)
        #expect(LevelStep.percent(-1) == 0)
    }

    @Test func volumeKeysMoveTheState() {
        let muted = VolumeState(level: 0.5, isMuted: true)
        #expect(muted.applying(.volumeUp, fine: false) == VolumeState(level: 0.5625, isMuted: false))
        #expect(muted.applying(.volumeDown, fine: false) == VolumeState(level: 0.4375, isMuted: true))
        #expect(muted.applying(.mute, fine: false) == VolumeState(level: 0.5, isMuted: false))
        #expect(VolumeState(level: 0.5, isMuted: false).applying(.mute, fine: true).isMuted)
        #expect(muted.applying(.brightnessUp, fine: false) == muted)
        #expect(VolumeState(level: 0, isMuted: false).isSilent)
    }
}

struct VolumeTrackerTests {
    @Test func aDeviceThatRoundsUpCantHoldTheVolumeDown() {
        var tracker = VolumeTracker()
        let start = Date(timeIntervalSince1970: 0)
        // The device rounds 0.6875 up to 0.6944: from its reading, a step down lands back
        // on 0.6875 again and again. From Cleen's own level, it keeps going.
        var level = 0.6944
        for press in 0..<3 {
            let now = start.addingTimeInterval(Double(press) * 0.2)
            let next = LevelStep.next(tracker.base(reading: 0.6944, now: now), up: false, fine: false)
            tracker.record(next, now: now)
            level = next
        }
        #expect(abs(level - 0.5625) < 1e-9)
    }

    @Test func aQuickBurstIgnoresStaleReadings() {
        var tracker = VolumeTracker()
        let now = Date(timeIntervalSince1970: 0)
        tracker.record(0.75, now: now)
        // The device hasn't applied the last presses yet and still says 0.5.
        #expect(tracker.base(reading: 0.5, now: now.addingTimeInterval(0.3)) == 0.75)
    }

    @Test func aChangeMadeElsewhereWins() {
        var tracker = VolumeTracker()
        let now = Date(timeIntervalSince1970: 0)
        tracker.record(0.75, now: now)
        #expect(tracker.base(reading: 0.3, now: now.addingTimeInterval(10)) == 0.3)
        // Only rounded by the device: still Cleen's level.
        #expect(tracker.base(reading: 0.765, now: now.addingTimeInterval(10)) == 0.75)
    }
}
