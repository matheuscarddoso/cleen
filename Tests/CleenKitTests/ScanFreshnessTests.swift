import Foundation
import Testing
@testable import CleenKit

@Suite struct ScanFreshnessTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aScanNeverTakenIsDue() {
        #expect(ScanFreshness.isDue(lastScan: nil, now: now))
    }

    @Test func aRecentScanStands() {
        #expect(!ScanFreshness.isDue(lastScan: now, now: now))
        #expect(!ScanFreshness.isDue(lastScan: now.addingTimeInterval(-ScanFreshness.maxAge), now: now))
    }

    @Test func anOldScanIsDue() {
        #expect(ScanFreshness.isDue(lastScan: now.addingTimeInterval(-ScanFreshness.maxAge - 1), now: now))
        #expect(ScanFreshness.isDue(lastScan: now.addingTimeInterval(-86_400), now: now))
    }

    @Test func aScanFromTheFutureIsDue() {
        // The clock was set back after the scan.
        #expect(ScanFreshness.isDue(lastScan: now.addingTimeInterval(3_600), now: now))
    }
}
