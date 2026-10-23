import Foundation
import Testing
@testable import CleenKit

struct SafetyGuardTests {
    let sandbox: Sandbox
    let safety: SafetyGuard

    init() throws {
        sandbox = try Sandbox()
        safety = SafetyGuard(home: sandbox.root)
    }

    @Test(arguments: ["", "Library", "Library/Caches", "Documents", "Downloads", "Desktop", ".ssh", "Library/Containers"])
    func refusesEssentialHomeFolders(_ path: String) {
        #expect(throws: SafetyGuard.Violation.self) {
            try safety.validate(path.isEmpty ? sandbox.root : sandbox.url(path))
        }
    }

    @Test(arguments: ["/", "/System", "/System/Library/CoreServices", "/Applications", "/Applications/Utilities", "/usr/bin", "/Library", "/Users"])
    func refusesSystemLocations(_ path: String) {
        #expect(throws: SafetyGuard.Violation.self) { try safety.validate(URL(filePath: path)) }
    }

    @Test func refusesAnythingOutsideHomeAndAppFolders() {
        #expect(throws: SafetyGuard.Violation.outsideAllowedRoots("/etc/hosts")) {
            try safety.validate(URL(filePath: "/etc/hosts"))
        }
        #expect(throws: SafetyGuard.Violation.self) {
            try safety.validate(URL(filePath: "/Volumes/External/photos"))
        }
    }

    @Test(arguments: [
        "Library/Mobile Documents/com~apple~CloudDocs", "Library/Mobile Documents/iCloud~md~obsidian",
        "Library/CloudStorage/Dropbox", "Pictures/Photos Library.photoslibrary",
    ])
    func refusesSyncedRootsAndPhotosLibraries(_ path: String) throws {
        let folder = try sandbox.folder(path)
        #expect(throws: SafetyGuard.Violation.self) { try safety.validate(folder) }
    }

    @Test func allowsFilesInsideSyncedFolders() throws {
        let file = try sandbox.file("Library/Mobile Documents/com~apple~CloudDocs/old.zip")
        #expect(try safety.validate(file).lastPathComponent == "old.zip")
    }

    @Test func judgesDataVolumePathsByTheirUsualPath() throws {
        let file = try sandbox.file("Downloads/setup.dmg")
        let onDataVolume = URL(filePath: "/System/Volumes/Data" + file.resolvingSymlinksInPath().path(percentEncoded: false))
        #expect(try safety.validate(onDataVolume).lastPathComponent == "setup.dmg")
        #expect(throws: SafetyGuard.Violation.self) { try safety.validate(URL(filePath: "/System/Volumes/Data/System/Library")) }
    }

    @Test func allowsItemsInsideCleanableFolders() throws {
        let cache = try sandbox.folder("Library/Caches/com.example.app")
        #expect(try safety.validate(cache).lastPathComponent == "com.example.app")
        let download = try sandbox.file("Downloads/setup.dmg")
        #expect(try safety.validate(download).lastPathComponent == "setup.dmg")
    }

    @Test func allowsAppBundlesAndLooseFilesInApplications() throws {
        #expect(try safety.validate(URL(filePath: "/Applications/Example.app")).path == "/Applications/Example.app")
        #expect(try safety.validate(URL(filePath: "/Applications/installer.dmg")).path == "/Applications/installer.dmg")
    }

    @Test func symlinkInThePathCannotReachProtectedPlaces() throws {
        try FileManager.default.createSymbolicLink(at: sandbox.url("escape"), withDestinationURL: URL(filePath: "/System"))
        #expect(throws: SafetyGuard.Violation.self) {
            try safety.validate(sandbox.url("escape/Library"))
        }
    }

    @Test func relativePathsAreRejected() {
        #expect(throws: SafetyGuard.Violation.self) { try safety.validate(URL(filePath: "Library/Caches", relativeTo: nil)) }
    }
}
