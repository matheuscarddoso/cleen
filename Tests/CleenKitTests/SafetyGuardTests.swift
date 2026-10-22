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
