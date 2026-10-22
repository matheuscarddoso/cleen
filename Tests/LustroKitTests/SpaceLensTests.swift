import Foundation
import Testing
@testable import LustroKit

struct SpaceLensTests {
    @Test func foldsSmallEntriesAndKeepsBigOnesNavigable() throws {
        let sandbox = try Sandbox()
        try sandbox.file("disk/videos/a.mov", bytes: 2_000_000)
        try sandbox.file("disk/videos/b.mov", bytes: 2_000_000)
        for index in 0..<5 {
            try sandbox.file("disk/notes/\(index).txt", bytes: 1_000)
        }
        try sandbox.file("disk/big.iso", bytes: 3_000_000)

        let result = try #require(SpaceLensScanner(root: sandbox.url("disk"), minimumNodeSize: 1_000_000).scan())
        let root = result.root
        #expect(root.children.map(\.name).prefix(2) == ["videos", "big.iso"])

        let videos = try #require(root.children.first { $0.name == "videos" })
        #expect(videos.isNavigable)
        #expect(videos.children.count == 2)

        // The notes folder is too small to stand alone and is folded into an aggregate.
        let folded = try #require(root.children.last)
        #expect(folded.isAggregate)
        #expect(root.size >= 7_000_000)
    }

    @Test func unreadableFoldersDoNotCorruptTheTree() throws {
        let sandbox = try Sandbox()
        try sandbox.file("disk/locked/secret.bin", bytes: 10_000)
        try sandbox.file("disk/after/data.bin", bytes: 2_000_000)
        let locked = sandbox.url("disk/locked").path(percentEncoded: false)
        chmod(locked, 0o000)
        defer { chmod(locked, 0o755) }

        let result = try #require(SpaceLensScanner(root: sandbox.url("disk"), minimumNodeSize: 1_000_000).scan())
        #expect(result.unreadable == 1)
        #expect(result.root.name == "disk")
        #expect(result.root.children.first?.name == "after")
    }
}

struct SpaceNodeRemovalTests {
    @Test func removingANodeShrinksEveryAncestor() {
        let leaf = SpaceNode(id: "/r/a/b/file", name: "file", size: 40, isDirectory: false, isAggregate: false, children: [])
        let other = SpaceNode(id: "/r/a/b/keep", name: "keep", size: 10, isDirectory: false, isAggregate: false, children: [])
        let b = SpaceNode(id: "/r/a/b", name: "b", size: 50, isDirectory: true, isAggregate: false, children: [leaf, other])
        let a = SpaceNode(id: "/r/a", name: "a", size: 60, isDirectory: true, isAggregate: false, children: [b])
        let root = SpaceNode(id: "/r", name: "r", size: 100, isDirectory: true, isAggregate: false, children: [a])

        let updated = root.removing("/r/a/b/file")
        #expect(updated.size == 60)
        #expect(updated.children[0].size == 20)
        #expect(updated.children[0].children[0].children.map(\.name) == ["keep"])
    }

    @Test func siblingsWithSharedPrefixesAreNotConfused() {
        let ab = SpaceNode(id: "/r/ab", name: "ab", size: 5, isDirectory: false, isAggregate: false, children: [])
        let a = SpaceNode(id: "/r/a", name: "a", size: 7, isDirectory: true, isAggregate: false, children: [])
        let root = SpaceNode(id: "/r", name: "r", size: 12, isDirectory: true, isAggregate: false, children: [a, ab])
        #expect(root.removing("/r/ab").children.map(\.name) == ["a"])
    }
}
