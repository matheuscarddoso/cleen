import Foundation
import Testing
@testable import CleenKit

struct FileSizerTests {
    @Test func sumsEveryFileInTheTree() throws {
        let sandbox = try Sandbox()
        try sandbox.file("tree/a.bin", bytes: 100_000)
        try sandbox.file("tree/nested/deeper/b.bin", bytes: 200_000)

        let size = FileSizer.allocatedSize(of: sandbox.url("tree"))
        #expect(size >= 300_000)
        #expect(size < 400_000)
    }

    @Test func countsHardLinkedFilesOnce() throws {
        let sandbox = try Sandbox()
        let original = try sandbox.file("tree/original.bin", bytes: 500_000)
        try FileManager.default.linkItem(at: original, to: sandbox.url("tree/link.bin"))

        let size = FileSizer.allocatedSize(of: sandbox.url("tree"))
        #expect(size < 1_000_000)
    }

    @Test func doesNotFollowSymlinks() throws {
        let sandbox = try Sandbox()
        try sandbox.file("big/payload.bin", bytes: 2_000_000)
        try sandbox.folder("tree")
        try FileManager.default.createSymbolicLink(at: sandbox.url("tree/link"), withDestinationURL: sandbox.url("big"))

        #expect(FileSizer.allocatedSize(of: sandbox.url("tree")) < 100_000)
    }

    @Test func missingPathIsZero() throws {
        let sandbox = try Sandbox()
        #expect(FileSizer.allocatedSize(of: sandbox.url("nope")) == 0)
        #expect(!FileSizer.exists(sandbox.url("nope")))
    }
}
