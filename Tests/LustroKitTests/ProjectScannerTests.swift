import Foundation
import Testing
@testable import LustroKit

struct ProjectScannerTests {
    @Test func findsDependencyFoldersOnlyWhereTheirManifestExists() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("code/web/package.json", bytes: 100)
        try sandbox.file("code/web/node_modules/react/index.js", bytes: 40_000)
        try sandbox.file("code/web/node_modules/react/node_modules/inner/index.js", bytes: 40_000)
        try sandbox.file("code/api/composer.json", bytes: 100)
        try sandbox.file("code/api/vendor/laravel/framework.php", bytes: 40_000)
        // A folder that merely happens to be called "vendor" is not an artifact.
        try sandbox.file("code/notes/vendor/invoice.pdf", bytes: 40_000)
        try sandbox.file("code/tool/Cargo.toml", bytes: 100)
        try sandbox.file("code/tool/target/debug/tool", bytes: 40_000)

        let projects = await ProjectScanner(roots: [sandbox.url("code")]).scan()
        let found = Dictionary(uniqueKeysWithValues: projects.map { ($0.name, $0.artifacts.map(\.kind)) })

        #expect(found["web"] == [.nodeModules])
        #expect(found["api"] == [.composerVendor])
        #expect(found["tool"] == [.cargoTarget])
        #expect(found["notes"] == nil)
        // Nested node_modules belong to the outer one, not a project of their own.
        #expect(projects.count == 3)
    }

    @Test func virtualenvNeedsItsMarkerFile() async throws {
        let sandbox = try Sandbox()
        try sandbox.file("code/ml/.venv/pyvenv.cfg", bytes: 100)
        try sandbox.file("code/ml/.venv/lib/torch.so", bytes: 40_000)
        try sandbox.file("code/other/venv/readme.txt", bytes: 40_000)

        let projects = await ProjectScanner(roots: [sandbox.url("code")]).scan()
        #expect(projects.map(\.name) == ["ml"])
        #expect(projects.first?.artifacts.first?.kind.selectedWhenStale == false)
    }

    @Test func activityIgnoresTheArtifactsThemselves() throws {
        let sandbox = try Sandbox()
        let old = Date.now.addingTimeInterval(-90 * 86_400)
        let manifest = try sandbox.file("web/package.json", bytes: 100)
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: manifest.path(percentEncoded: false))
        try sandbox.file("web/node_modules/fresh.js", bytes: 100)

        let activity = ProjectScanner.lastActivity(of: sandbox.url("web"), ignoring: ["node_modules"])
        #expect(abs(activity.timeIntervalSince(old)) < 2)
    }
}
