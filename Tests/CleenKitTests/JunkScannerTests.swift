import Foundation
import Testing
@testable import CleenKit

struct JunkScannerTests {
    @Test func specificSourcesWinOverGenericOnes() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("Library/Caches/com.example.editor/blob", bytes: 50_000)
        try sandbox.file("Library/Caches/Homebrew/downloads/pkg.tar.gz", bytes: 80_000)
        try sandbox.file("Library/Caches/Google/Chrome/Default/Cache/data", bytes: 60_000)
        try sandbox.file("Library/Caches/Google/DriveFS/data", bytes: 40_000)

        let results = await JunkScanner(home: sandbox.root, systemRoot: sandbox.url("system")).scan()
        let appCaches = try #require(results.first { $0.id == "app-caches" })
        let names = Set(appCaches.items.map(\.name))

        #expect(names == ["com.example.editor", "DriveFS"])
        #expect(results.first { $0.id == "package-managers" }?.items.map(\.name) == ["Homebrew"])
        #expect(results.first { $0.id == "browser-caches" }?.items.map(\.name) == ["Chrome"])
    }

    @Test func excludedSystemCachesAreNeverOffered() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("Library/Caches/CloudKit/state.db", bytes: 50_000)
        try sandbox.file("Library/Caches/com.apple.bird/state", bytes: 50_000)
        try sandbox.file("Library/Caches/com.example.app/blob", bytes: 50_000)

        let results = await JunkScanner(home: sandbox.root, systemRoot: sandbox.url("system")).scan()
        let names = results.flatMap(\.items).map(\.name)
        #expect(names == ["com.example.app"])
    }

    @Test func cachesOfRunningAppsStartUnselected() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("Library/Caches/com.example.running/blob", bytes: 50_000)
        try sandbox.file("Library/Caches/com.example.idle/blob", bytes: 50_000)

        let results = await JunkScanner(home: sandbox.root, runningBundleIDs: ["com.example.running"], systemRoot: sandbox.url("system")).scan()
        let items = try #require(results.first).items
        let running = try #require(items.first { $0.name == "com.example.running" })
        let idle = try #require(items.first { $0.name == "com.example.idle" })

        #expect(!running.selectedByDefault)
        #expect(running.note != nil)
        #expect(idle.selectedByDefault)
    }

    @Test func installersOnlyMatchTheirExtensionsAndGoToTrash() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("Downloads/Tool.dmg", bytes: 30_000)
        try sandbox.file("Downloads/Contract.pdf", bytes: 30_000)
        try sandbox.folder("Downloads/Folder.pkg")

        let results = await JunkScanner(home: sandbox.root, systemRoot: sandbox.url("system")).scan()
        let installers = try #require(results.first { $0.id == "installers" })
        #expect(installers.items.map(\.name) == ["Tool.dmg"])
        #expect(installers.items.allSatisfy { $0.removal == .trash })
    }

    @Test func emptyCategoriesAreOmitted() async throws {
        let sandbox = try Sandbox()
        #expect(await JunkScanner(home: sandbox.root, systemRoot: sandbox.url("system")).scan().isEmpty)
    }

    @Test func everyDeletingCategoryPassesTheSafetyGuard() throws {
        // No source may point at a folder the guard protects: the scanner would offer
        // the folder itself and every cleanup of it would fail.
        let safety = SafetyGuard(home: Paths.home)
        for source in JunkCatalog.all.flatMap(\.sources) where source.shape == .whole {
            let url = Paths.expand(source.path)
            #expect(throws: Never.self, "\(source.path)") { try safety.validate(url) }
        }
    }
}
