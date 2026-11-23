import Foundation
import Testing
@testable import CleenKit

struct UpdateTests {
    @Test func comparesVersionsNumberByNumber() {
        #expect(AppVersion("1.10.0") > AppVersion("1.9.9"))
        #expect(AppVersion("v1.2") == AppVersion("1.2.0"))
        #expect(AppVersion("1.2.0-3-gabc") == AppVersion("1.2.0"))
        #expect(AppVersion("2.0") > AppVersion("1.99.99"))
    }

    @Test func feedDecidesWhetherToUpdate() throws {
        let json = #"{"version":"1.2.0","build":58,"url":"https://example.com/Cleen-1.2.0.dmg","sha256":"ab","notes":"Novidades","minimumSystemVersion":"26.0"}"#
        let feed = try JSONDecoder().decode(UpdateFeed.self, from: Data(json.utf8))
        let tahoe = OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)
        #expect(feed.isUpdate(over: "1.1.0", system: tahoe))
        #expect(!feed.isUpdate(over: "1.2.0", system: tahoe))
        #expect(!feed.isUpdate(over: "1.1.0", system: OperatingSystemVersion(majorVersion: 15, minorVersion: 6, patchVersion: 0)))
    }

    @Test func updatesOnlyFromTheSameTeamOrItsSuccessor() {
        // The same team, as every update until now.
        #expect(UpdateSigner.accepts("9QGGX38JS2", replacing: "9QGGX38JS2"))
        #expect(UpdateSigner.accepts("AS86DUYNV9", replacing: "AS86DUYNV9"))
        // The bridge build, signed by the old team, takes the first notarized one.
        #expect(UpdateSigner.accepts("AS86DUYNV9", replacing: "9QGGX38JS2"))
        // Never back, never a stranger, never unsigned.
        #expect(!UpdateSigner.accepts("9QGGX38JS2", replacing: "AS86DUYNV9"))
        #expect(!UpdateSigner.accepts("ZZZZZZZZZZ", replacing: "9QGGX38JS2"))
        #expect(!UpdateSigner.accepts(nil, replacing: "9QGGX38JS2"))
        #expect(!UpdateSigner.accepts("", replacing: "9QGGX38JS2"))
        #expect(!UpdateSigner.accepts("AS86DUYNV9", replacing: nil))
    }
}
