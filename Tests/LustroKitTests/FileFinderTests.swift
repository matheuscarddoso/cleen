import Foundation
import Testing
@testable import LustroKit

struct FileFinderTests {
    @Test func largeFilesSkipLibraryAndDependencyFolders() throws {
        let sandbox = try Sandbox()
        try sandbox.file("Movies/trip.mov", bytes: 3_000_000)
        try sandbox.file("Downloads/small.txt", bytes: 10_000)
        try sandbox.file("Library/Application Support/App/huge.db", bytes: 3_000_000)
        try sandbox.file("Projects/web/node_modules/big.wasm", bytes: 3_000_000)

        let files = LargeFileScanner(root: sandbox.root, minimumSize: 1_000_000, home: sandbox.root).scan()
        #expect(files.map(\.name) == ["trip.mov"])
        #expect(files.first?.kind == .video)
    }

    @Test func duplicatesAreGroupedByContentNotByName() throws {
        let sandbox = try Sandbox()
        try sandbox.file("Downloads/photo.jpg", bytes: 1_500_000, fill: 7)
        try sandbox.file("Desktop/photo copy.jpg", bytes: 1_500_000, fill: 7)
        try sandbox.file("Documents/archive/IMG_1.jpg", bytes: 1_500_000, fill: 7)
        // Same size, different bytes: not a duplicate.
        try sandbox.file("Documents/other.jpg", bytes: 1_500_000, fill: 9)

        let groups = DuplicateFinder(roots: [sandbox.url("Downloads"), sandbox.url("Desktop"), sandbox.url("Documents")]).scan()
        let group = try #require(groups.first)
        #expect(groups.count == 1)
        #expect(group.files.count == 3)
        #expect(group.wasted == 3_000_000)
    }

    @Test func differencesAfterTheFirstBlockAreCaught() throws {
        let sandbox = try Sandbox()
        var head = Data(repeating: 1, count: 2_000_000)
        try head.write(to: sandbox.url("a.bin"))
        head[1_999_999] = 2
        try head.write(to: sandbox.url("b.bin"))

        #expect(DuplicateFinder(roots: [sandbox.root]).scan().isEmpty)
    }

    @Test func hardLinksAreNotDuplicates() throws {
        let sandbox = try Sandbox()
        let original = try sandbox.file("a.bin", bytes: 1_500_000)
        try FileManager.default.linkItem(at: original, to: sandbox.url("b.bin"))
        #expect(DuplicateFinder(roots: [sandbox.root]).scan().isEmpty)
    }

    @Test(arguments: [("mov", FileKind.video), ("dmg", .installer), ("zip", .archive), ("png", .image), ("pdf", .document), ("xyz123", .other)])
    func kindsFollowFileTypes(ext: String, kind: FileKind) {
        #expect(FileKind(fileExtension: ext) == kind)
    }
}
