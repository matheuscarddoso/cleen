import Foundation
import Testing
@testable import LustroKit

struct AppLeftoverTests {
    @Test(arguments: [
        "com.tinyspeck.slackmacgap",
        "com.tinyspeck.slackmacgap.plist",
        "com.tinyspeck.slackmacgap.savedState",
        "BQR82RBBHL.com.tinyspeck.slackmacgap",
        "com.tinyspeck.slackmacgap.ShipIt",
    ])
    func matchesTheBundleIdentifierInAllItsShapes(_ name: String) {
        #expect(LeftoverFinder.matches(name, bundleID: "com.tinyspeck.slackmacgap", names: []))
    }

    @Test(arguments: ["com.tinyspeck.slackmacgapX", "com.tinyspeck", "Slack Helper", "SlackHelper"])
    func rejectsLookalikes(_ name: String) {
        #expect(!LeftoverFinder.matches(name, bundleID: "com.tinyspeck.slackmacgap", names: ["Slack"]))
    }

    @Test func findsLeftoversAcrossTheLibrary() throws {
        let sandbox = try Sandbox()
        try sandbox.file("Library/Application Support/Slack/storage", bytes: 20_000)
        try sandbox.file("Library/Preferences/com.tinyspeck.slackmacgap.plist", bytes: 1_000)
        try sandbox.file("Library/Caches/com.tinyspeck.slackmacgap/cache", bytes: 20_000)
        try sandbox.file("Library/Saved Application State/com.tinyspeck.slackmacgap.savedState/data", bytes: 1_000)
        try sandbox.file("Library/Application Support/Slackware/keep", bytes: 20_000)
        // "Slack" in Preferences only matches by identifier, never by name.
        try sandbox.file("Library/Preferences/Slack", bytes: 1_000)

        let finder = LeftoverFinder(home: sandbox.root, systemLibrary: sandbox.url("SystemLibrary"))
        let found = finder.leftovers(bundleID: "com.tinyspeck.slackmacgap", names: ["Slack"])
        let places = Set(found.map(\.place))

        #expect(found.count == 4)
        #expect(places == [.applicationSupport, .preferences, .caches, .savedState])
    }

    @Test(arguments: [
        ("com.spotify.client", "com.spotify.client"),
        ("com.spotify.client.plist", "com.spotify.client"),
        ("com.spotify.client.savedState", "com.spotify.client"),
    ])
    func extractsIdentifiersFromFileNames(file: String, expected: String) {
        #expect(OrphanFinder.bundleID(from: file, suffixes: [".plist", ".savedState"]) == expected)
    }

    @Test(arguments: ["com.apple.Safari", "Google", "group.com.example.shared", "com.example", "My App Data", "README.txt"])
    func ignoresNamesThatAreNotThirdPartyAppIdentifiers(_ file: String) {
        #expect(OrphanFinder.bundleID(from: file, suffixes: [".plist"]) == nil)
    }

    @Test func orphansNeedTracesOfARealApp() throws {
        let sandbox = try Sandbox()
        // Uninstalled GUI app: window state proves it was an app.
        try sandbox.file("Library/Caches/com.gone.editor/cache", bytes: 20_000)
        try sandbox.file("Library/Saved Application State/com.gone.editor.savedState/data", bytes: 1_000)
        // A CLI tool's cache: no app evidence, must not be offered.
        try sandbox.file("Library/Caches/com.vendor.cli-tool/cache", bytes: 20_000)
        // Installed app's data stays.
        try sandbox.file("Library/Caches/com.present.app/cache", bytes: 20_000)
        try sandbox.file("Library/Saved Application State/com.present.app.savedState/data", bytes: 1_000)

        let groups = OrphanFinder(home: sandbox.root, installedBundleIDs: ["com.present.app"]).scan()
        #expect(groups.map(\.bundleID) == ["com.gone.editor"])
        #expect(groups.first?.items.count == 2)
        #expect(groups.first?.displayName == "Editor")
    }
}
