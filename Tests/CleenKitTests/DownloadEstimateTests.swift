import Foundation
import Testing
@testable import CleenKit

struct DownloadEstimateTests {
    @Test func estimatesOnceItHasMeasuredLongEnough() throws {
        var estimate = DownloadEstimate()
        let start = Date(timeIntervalSince1970: 0)
        // 1 MB/s steady, 100 MB total.
        for second in 0...4 {
            estimate.update(completed: Int64(second) * 1_000_000, total: 100_000_000, at: start.addingTimeInterval(Double(second)))
            if second < 2 { #expect(estimate.remaining == nil) }
        }
        let remaining = try #require(estimate.remaining)
        #expect(abs(remaining - 96) < 1)
        #expect(estimate.fraction == 0.04)
    }

    @Test func aBurstMovesTheSpeedOnlyPartWay() throws {
        var estimate = DownloadEstimate()
        let start = Date(timeIntervalSince1970: 0)
        for second in 0...3 {
            estimate.update(completed: Int64(second) * 1_000_000, total: 0, at: start.addingTimeInterval(Double(second)))
        }
        // A one-second burst at 9 MB/s.
        estimate.update(completed: 12_000_000, total: 0, at: start.addingTimeInterval(4))
        let speed = try #require(estimate.speed)
        #expect(speed > 1_000_000 && speed < 4_000_000)
        // Without a size, no time left.
        #expect(estimate.remaining == nil)
    }

    @Test func browsersUnfinishedNames() {
        #expect(DownloadEstimate.finalName(of: "Launch Assets.zip.crdownload") == "Launch Assets.zip")
        #expect(DownloadEstimate.finalName(of: "Foto.jpg.download") == "Foto.jpg")
        #expect(DownloadEstimate.finalName(of: "song.mp3.part") == "song.mp3")
        #expect(DownloadEstimate.finalName(of: "relatorio.pdf") == "relatorio.pdf")
    }
}
