import Foundation
import Testing
@testable import CleenKit

struct OrderedJSONTests {
    /// Written the way Claude Code writes it (`JSON.stringify(value, null, 2)`).
    static let claudeWritten = """
    {
      "model": "opus",
      "permissions": {
        "allow": [
          "Bash(npm test:*)",
          "Read(//Users/me/**)"
        ],
        "deny": []
      },
      "env": {},
      "statusLine": {
        "type": "command",
        "command": "~/.claude/statusline.sh \\"$1\\"",
        "padding": 0
      },
      "cleanupPeriodDays": 1.50,
      "feedbackSurveyRate": 1e-3,
      "alwaysThinkingEnabled": true,
      "theme": null,
      "spinnerVerbs": [
        "Cozinhando",
        "Pensando… ☕️",
        "tab\\there"
      ]
    }

    """

    @Test func roundTripIsByteForByte() throws {
        let value = try JSONValue.parse(Self.claudeWritten)
        #expect(value.printed(.detect(in: Self.claudeWritten)) == Self.claudeWritten)
    }

    @Test func keepsKeyOrderAndNumberSpelling() throws {
        let value = try JSONValue.parse(#"{"z":1.0,"a":2,"m":-0.5e10}"#)
        #expect(value.objectValue?.map(\.key) == ["z", "a", "m"])
        #expect(value["z"] == .number("1.0"))
        #expect(value.printed(.detect(in: #"{"z":1.0,"a":2,"m":-0.5e10}"#)) == #"{"z":1.0,"a":2,"m":-0.5e10}"#)
    }

    @Test func detectsTabsAndFourSpaces() throws {
        let tabs = "{\n\t\"a\": [\n\t\t1\n\t]\n}"
        #expect(try JSONValue.parse(tabs).printed(.detect(in: tabs)) == tabs)
        let four = "{\n    \"a\": {\n        \"b\": \"c\"\n    }\n}\n"
        #expect(try JSONValue.parse(four).printed(.detect(in: four)) == four)
    }

    @Test func decodesEscapesAndSurrogatePairs() throws {
        let value = try JSONValue.parse(#"{"s":"\u00e9\ud83d\ude00\/\n"}"#)
        #expect(value["s"]?.stringValue == "é😀/\n")
        // Printed as JSON.stringify would: no escaping of "/" or non-ASCII.
        #expect(value.printed(.init(indent: nil, trailingNewline: false)) == "{\"s\":\"é😀/\\n\"}")
    }

    @Test func controlCharactersUseLowercaseHex() {
        #expect(JSONValue.string("\u{1B}").printed(.init(indent: nil, trailingNewline: false)) == #""\u001b""#)
    }

    @Test func reportsWhereItBroke() {
        #expect(throws: JSONParseError.self) { try JSONValue.parse("{\n  \"a\": 1,\n}") }
        do {
            _ = try JSONValue.parse("{\n  \"a\": 1,\n  // comment\n}")
            Issue.record("should not parse")
        } catch {
            #expect(error.line == 3)
        }
        #expect(throws: JSONParseError.self) { try JSONValue.parse("{\"a\": 1} trailing") }
        #expect(throws: JSONParseError.self) { try JSONValue.parse("[1, 2") }
        #expect(throws: JSONParseError.self) { try JSONValue.parse("\"\\ud83d\"") }
    }
}

struct ClaudeHookSettingsTests {
    static let command = ClaudeHookSettings.command(for: URL(filePath: "/Users/me/Library/Application Support/Cleen/hooks/claude-permission"))

    /// Another tool's hooks, which must come through untouched.
    static let withOtherHooks = """
    {
      "hooks": {
        "PreToolUse": [
          {
            "matcher": "Bash",
            "hooks": [
              {
                "type": "command",
                "command": "~/.notchi/hook.sh"
              }
            ]
          }
        ],
        "PermissionRequest": [
          {
            "matcher": "ExitPlanMode",
            "hooks": [
              {
                "type": "command",
                "command": "echo ok"
              }
            ]
          }
        ]
      },
      "model": "opus"
    }

    """

    @Test func commandIsQuotedForTheShell() {
        #expect(Self.command == "'/Users/me/Library/Application Support/Cleen/hooks/claude-permission'")
        #expect(ClaudeHookSettings.shellQuoted("it's") == #"'it'\''s'"#)
    }

    @Test func installsNextToOtherToolsAndRemovesCleanly() throws {
        let installed = try ClaudeHookSettings.installing(into: Self.withOtherHooks, command: Self.command)
        #expect(ClaudeHookSettings.isInstalled(in: installed))
        #expect(!ClaudeHookSettings.isInstalled(in: Self.withOtherHooks))

        let root = try JSONValue.parse(installed)
        #expect(root.objectValue?.map(\.key) == ["hooks", "model"])
        let groups = try #require(root["hooks"]?["PermissionRequest"]?.arrayValue)
        #expect(groups.count == 2)
        #expect(groups[0]["matcher"]?.stringValue == "ExitPlanMode")
        #expect(groups[1]["matcher"]?.stringValue == ClaudeHookSettings.matcher)
        let handler = try #require(groups[1]["hooks"]?.arrayValue?.first)
        #expect(handler["command"]?.stringValue == Self.command)
        #expect(handler["timeout"] == .number("120"))
        #expect(root["hooks"]?["PreToolUse"] == (try JSONValue.parse(Self.withOtherHooks))["hooks"]?["PreToolUse"])

        // Removing gives back the file exactly as it was.
        #expect(try ClaudeHookSettings.removing(from: installed) == Self.withOtherHooks)
    }

    @Test func installingTwiceKeepsOneEntry() throws {
        let once = try ClaudeHookSettings.installing(into: Self.withOtherHooks, command: Self.command)
        let twice = try ClaudeHookSettings.installing(into: once, command: Self.command)
        #expect(once == twice)
        // A moved script replaces the old entry in place.
        let moved = try ClaudeHookSettings.installing(into: once, command: "'/Other/Cleen/hooks/claude-permission'")
        let groups = try #require(JSONValue.parse(moved)["hooks"]?["PermissionRequest"]?.arrayValue)
        #expect(groups.count == 2)
        #expect(groups[1]["hooks"]?.arrayValue?.first?["command"]?.stringValue == "'/Other/Cleen/hooks/claude-permission'")
    }

    @Test func noHooksKeyYet() throws {
        let original = "{\n  \"model\": \"opus\"\n}\n"
        let installed = try ClaudeHookSettings.installing(into: original, command: Self.command)
        #expect(try JSONValue.parse(installed).objectValue?.map(\.key) == ["model", "hooks"])
        #expect(try ClaudeHookSettings.removing(from: installed) == original)
    }

    @Test func emptyOrMissingFile() throws {
        for text in [nil, "", "  \n"] {
            let installed = try ClaudeHookSettings.installing(into: text, command: Self.command)
            #expect(ClaudeHookSettings.isInstalled(in: installed))
            #expect(try ClaudeHookSettings.removing(from: installed) == "{}\n")
        }
    }

    @Test func malformedFilesAreRefused() {
        #expect(throws: ClaudeHookSettings.Failure.malformed(line: 3)) {
            try ClaudeHookSettings.installing(into: "{\n  \"a\": 1,\n}", command: Self.command)
        }
        #expect(throws: ClaudeHookSettings.Failure.unexpectedShape(path: "/")) {
            try ClaudeHookSettings.installing(into: "[]", command: Self.command)
        }
        #expect(throws: ClaudeHookSettings.Failure.unexpectedShape(path: "hooks")) {
            try ClaudeHookSettings.installing(into: #"{"hooks": []}"#, command: Self.command)
        }
        #expect(throws: ClaudeHookSettings.Failure.unexpectedShape(path: "hooks.PermissionRequest")) {
            try ClaudeHookSettings.installing(into: #"{"hooks": {"PermissionRequest": {}}}"#, command: Self.command)
        }
        #expect(throws: ClaudeHookSettings.Failure.malformed(line: 1)) {
            try ClaudeHookSettings.removing(from: "{")
        }
    }

    @Test func removingLeavesOthersInASharedGroup() throws {
        let shared = """
        {"hooks":{"PermissionRequest":[{"matcher":"*","hooks":[{"type":"command","command":"other"},{"type":"command","command":\(JSONValue.string(Self.command).printed(.init(indent: nil, trailingNewline: false)))}]}]}}
        """
        let removed = try ClaudeHookSettings.removing(from: shared)
        #expect(removed == #"{"hooks":{"PermissionRequest":[{"matcher":"*","hooks":[{"type":"command","command":"other"}]}]}}"#)
    }

    @Test func removingWithoutCleenChangesNothing() throws {
        #expect(try ClaudeHookSettings.removing(from: Self.withOtherHooks) == Self.withOtherHooks)
        let odd = "{ \"a\" :1 }"
        #expect(try ClaudeHookSettings.removing(from: odd) == odd)
    }
}

struct ClaudeHookInstallerTests {
    private func installer(_ sandbox: Sandbox) -> ClaudeHookInstaller {
        ClaudeHookInstaller(
            settings: sandbox.url(".claude/settings.json"),
            script: sandbox.url("Support/Cleen/hooks/claude-permission"),
            socket: sandbox.url("Support/Cleen/agent.sock")
        )
    }

    @Test func installBacksUpAndRemoveRestores() throws {
        let sandbox = try Sandbox()
        let installer = installer(sandbox)
        #expect(installer.status() == .claudeCodeMissing)
        #expect(throws: ClaudeHookInstaller.Failure.claudeCodeMissing) { try installer.install() }

        try sandbox.folder(".claude")
        try Data(ClaudeHookSettingsTests.withOtherHooks.utf8).write(to: installer.settings)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: installer.settings.path)
        #expect(installer.status() == .notInstalled)

        try installer.install()
        #expect(installer.status() == .installed)
        #expect(try String(contentsOf: installer.backup, encoding: .utf8) == ClaudeHookSettingsTests.withOtherHooks)
        let permissions = try FileManager.default.attributesOfItem(atPath: installer.settings.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
        #expect(FileManager.default.isExecutableFile(atPath: installer.script.path))

        try FileManager.default.removeItem(at: installer.script)
        #expect(installer.status() == .incomplete)
        try installer.install()

        try installer.uninstall()
        #expect(installer.status() == .notInstalled)
        #expect(try String(contentsOf: installer.settings, encoding: .utf8) == ClaudeHookSettingsTests.withOtherHooks)
        #expect(!sandbox.exists("Support/Cleen/hooks"))
    }

    @Test func malformedFileIsLeftAlone() throws {
        let sandbox = try Sandbox()
        let installer = installer(sandbox)
        try sandbox.folder(".claude")
        let broken = "{\n  \"model\": \"opus\",\n}\n"
        try Data(broken.utf8).write(to: installer.settings)

        #expect(installer.status() == .unreadable(.malformed(line: 3)))
        #expect(throws: ClaudeHookInstaller.Failure.malformed(line: 3)) { try installer.install() }
        #expect(try String(contentsOf: installer.settings, encoding: .utf8) == broken)
        #expect(!sandbox.exists(".claude/settings.json.cleen-backup"))
        #expect(!sandbox.exists("Support/Cleen/hooks/claude-permission"))
    }

    @Test func notUTF8IsRefused() throws {
        let sandbox = try Sandbox()
        let installer = installer(sandbox)
        try sandbox.folder(".claude")
        try Data([0x7B, 0xFF, 0x7D]).write(to: installer.settings)
        #expect(throws: ClaudeHookInstaller.Failure.malformed(line: 1)) { try installer.install() }
    }

    @Test func writesThroughASymlink() throws {
        let sandbox = try Sandbox()
        let installer = installer(sandbox)
        try sandbox.folder(".claude")
        let real = sandbox.url("dotfiles/claude-settings.json")
        try sandbox.folder("dotfiles")
        try Data("{}\n".utf8).write(to: real)
        try FileManager.default.createSymbolicLink(at: installer.settings, withDestinationURL: real)

        try installer.install()
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: installer.settings.path) == real.path)
        #expect(ClaudeHookSettings.isInstalled(in: try String(contentsOf: real, encoding: .utf8)))
    }

    @Test func createsTheFileWhenClaudeCodeHasNone() throws {
        let sandbox = try Sandbox()
        let installer = installer(sandbox)
        try sandbox.folder(".claude")
        try installer.install()
        #expect(installer.status() == .installed)
        #expect(!sandbox.exists(".claude/settings.json.cleen-backup"))
    }
}

struct ClaudePermissionRequestTests {
    static let bash = #"""
    {"session_id":"abc123","transcript_path":"/Users/me/.claude/projects/x/abc123.jsonl","cwd":"/Users/me/Projects/loja","permission_mode":"default","hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf node_modules","description":"Remove node_modules directory"},"permission_suggestions":[{"type":"setMode","mode":"acceptEdits","destination":"session"},{"type":"addRules","rules":[{"toolName":"Bash","ruleContent":"rm -rf node_modules"}],"behavior":"allow","destination":"localSettings"}]}
    """#

    @Test func decodesTheDocumentedInput() throws {
        let request = try #require(ClaudePermissionRequest(json: Data(Self.bash.utf8)))
        #expect(request.sessionID == "abc123")
        #expect(request.projectName == "loja")
        #expect(request.toolName == "Bash")
        #expect(request.summary == ClaudeToolSummary(kind: .command, subject: "rm -rf node_modules", detail: "Remove node_modules directory", isCode: true))
        #expect(request.alwaysAllowDescription == "Bash(rm -rf node_modules)")
        #expect(request.alwaysAllowRule?["destination"]?.stringValue == "localSettings")
    }

    @Test func questionsAndOtherEventsStayInTheTerminal() {
        let question = Self.bash.replacing(#""tool_name":"Bash""#, with: #""tool_name":"AskUserQuestion""#)
        #expect(ClaudePermissionRequest(json: Data(question.utf8)) == nil)
        let preToolUse = Self.bash.replacing(#""hook_event_name":"PermissionRequest""#, with: #""hook_event_name":"PreToolUse""#)
        #expect(ClaudePermissionRequest(json: Data(preToolUse.utf8)) == nil)
        #expect(ClaudePermissionRequest(json: Data("not json".utf8)) == nil)
    }

    @Test func summaries() {
        let edit = ClaudeToolSummary(tool: "Edit", input: .object([JSONMember("file_path", .string("/Users/me/Projects/loja/src/app.ts"))]), directory: "/Users/me/Projects/loja")
        #expect(edit.kind == .edit)
        #expect(edit.subject == "src/app.ts")
        let outside = ClaudeToolSummary(tool: "Write", input: .object([JSONMember("file_path", .string(Paths.home.appending(path: "notes.md").path))]), directory: "/elsewhere")
        #expect(outside.subject == "~/notes.md")
        let fetch = ClaudeToolSummary(tool: "WebFetch", input: .object([JSONMember("url", .string("https://example.com")), JSONMember("prompt", .string("resuma"))]), directory: nil)
        #expect(fetch.subject == "https://example.com")
        let mcp = ClaudeToolSummary(tool: "mcp__github__create_issue", input: .object([JSONMember("count", .number("1")), JSONMember("title", .string("Bug"))]), directory: nil)
        #expect(mcp.kind == .mcp(server: "github", tool: "create_issue"))
        #expect(mcp.subject == "Bug")
    }

    @Test func decisionsMatchTheDocumentedOutput() throws {
        let allow = try JSONValue.parse(ClaudePermissionDecision.allow.output)
        #expect(allow["hookSpecificOutput"]?["hookEventName"]?.stringValue == "PermissionRequest")
        #expect(allow["hookSpecificOutput"]?["decision"]?["behavior"]?.stringValue == "allow")

        let request = try #require(ClaudePermissionRequest(json: Data(Self.bash.utf8)))
        let always = try JSONValue.parse(ClaudePermissionDecision.allowAlways(rule: try #require(request.alwaysAllowRule)).output)
        #expect(always["hookSpecificOutput"]?["decision"]?["updatedPermissions"]?.arrayValue == [try #require(request.alwaysAllowRule)])

        let deny = try JSONValue.parse(ClaudePermissionDecision.deny.output)
        #expect(deny["hookSpecificOutput"]?["decision"]?["behavior"]?.stringValue == "deny")
        #expect(deny["hookSpecificOutput"]?["decision"]?["interrupt"] == .bool(false))
    }
}

struct HookHTTPTests {
    @Test func parsesCurlsPost() {
        let head = "POST /claude/permission HTTP/1.1\r\nHost: cleen\r\nContent-Type: application/json\r\nContent-Length: 7\r\n\r\n"
        #expect(HookHTTP.parse(Data((head + "{\"a\":").utf8)) == .incomplete(expectsContinue: false))
        #expect(HookHTTP.parse(Data((head + "{\"a\":1}").utf8)) == .complete(Data("{\"a\":1}".utf8)))
        let expecting = "POST / HTTP/1.1\r\nContent-Length: 2\r\nExpect: 100-continue\r\n\r\n"
        #expect(HookHTTP.parse(Data(expecting.utf8)) == .incomplete(expectsContinue: true))
        #expect(HookHTTP.parse(Data("GET / HTTP/1.1\r\n\r\n".utf8)) == .invalid)
        #expect(HookHTTP.parse(Data("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)) == .invalid)
    }
}

/// The real script, the real `curl`, a real socket: what Claude Code would see.
@Suite(.serialized)
struct HookRoundTripTests {
    private final class Box: @unchecked Sendable {
        let lock = NSLock()
        var requests: [(UUID, Data)] = []
        var gone: [UUID] = []
    }

    private func runHook(_ script: URL, input: String) async throws -> (output: String, status: Int32) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = [script.path]
            let stdin = Pipe()
            let stdout = Pipe()
            process.standardInput = stdin
            process.standardOutput = stdout
            process.terminationHandler = { process in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (String(decoding: data, as: UTF8.self), process.terminationStatus))
            }
            do {
                try process.run()
                stdin.fileHandleForWriting.write(Data(input.utf8))
                try stdin.fileHandleForWriting.close()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func setUp() throws -> (Sandbox, ClaudeHookInstaller, URL) {
        // A hook that exits without reading its input closes the pipe under the write.
        signal(SIGPIPE, SIG_IGN)
        let sandbox = try Sandbox()
        // sockaddr_un holds 104 bytes; the test's temporary folder is too deep for it.
        let short = URL(filePath: "/tmp/cleen-\(UUID().uuidString.prefix(8))", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: short, withIntermediateDirectories: true)
        let installer = ClaudeHookInstaller(
            settings: sandbox.url(".claude/settings.json"),
            script: sandbox.url("hooks/claude-permission"),
            socket: short.appending(path: "agent.sock")
        )
        try sandbox.folder(".claude")
        try installer.install()
        return (sandbox, installer, short)
    }

    @Test func withoutCleenTheHookIsSilent() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        let result = try await runHook(installer.script, input: ClaudePermissionRequestTests.bash)
        #expect(result.output.isEmpty)
        #expect(result.status == 0)
    }

    @Test func aStaleSocketIsSilentToo() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        // Left behind as if Cleen had crashed: the file is there, nobody listens.
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            let bytes = Array(installer.socket.path.utf8)
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        close(fd)
        #expect(bound == 0)
        #expect(FileManager.default.fileExists(atPath: installer.socket.path))
        let result = try await runHook(installer.script, input: ClaudePermissionRequestTests.bash)
        #expect(result.output.isEmpty)
        #expect(result.status == 0)
        // And the next Cleen takes the path back.
        let next = HookSocketServer(path: installer.socket.path, lifetime: 30, onRequest: { _, _ in }, onGone: { _ in })
        try next.start()
        next.stop()
    }

    @Test func answersReachClaudeCode() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        let box = Box()
        let holder = ServerHolder()
        let server = HookSocketServer(path: installer.socket.path, lifetime: 30, onRequest: { id, body in
            box.lock.withLock { box.requests.append((id, body)) }
            holder.server?.respond(id, body: ClaudePermissionDecision.allow.output)
        }, onGone: { _ in })
        holder.server = server
        try server.start()
        defer { server.stop() }

        var info = stat()
        stat(installer.socket.path, &info)
        #expect(info.st_mode & 0o777 == 0o600)

        let result = try await runHook(installer.script, input: ClaudePermissionRequestTests.bash)
        #expect(result.status == 0)
        #expect(result.output == String(decoding: ClaudePermissionDecision.allow.output, as: UTF8.self))
        let received = box.lock.withLock { box.requests.first?.1 }
        #expect(received.flatMap { ClaudePermissionRequest(json: $0) }?.toolName == "Bash")
    }

    @Test func dismissingPrintsNothing() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        let holder = ServerHolder()
        let server = HookSocketServer(path: installer.socket.path, lifetime: 30, onRequest: { id, _ in
            holder.server?.respond(id, body: nil)
        }, onGone: { _ in })
        holder.server = server
        try server.start()
        defer { server.stop() }
        let result = try await runHook(installer.script, input: ClaudePermissionRequestTests.bash)
        #expect(result.output.isEmpty)
        #expect(result.status == 0)
    }

    @Test func unansweredRequestsExpire() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        let box = Box()
        let server = HookSocketServer(path: installer.socket.path, lifetime: 0.4, onRequest: { _, _ in }, onGone: { id in
            box.lock.withLock { box.gone.append(id) }
        })
        try server.start()
        defer { server.stop() }
        let result = try await runHook(installer.script, input: ClaudePermissionRequestTests.bash)
        #expect(result.output.isEmpty)
        #expect(box.lock.withLock { box.gone.count } == 1)
    }

    @Test func aLargeWriteGetsThrough() async throws {
        let (sandbox, installer, short) = try setUp()
        _ = sandbox
        defer { try? FileManager.default.removeItem(at: short) }
        let holder = ServerHolder()
        let box = Box()
        let server = HookSocketServer(path: installer.socket.path, lifetime: 30, onRequest: { id, body in
            box.lock.withLock { box.requests.append((id, body)) }
            holder.server?.respond(id, body: ClaudePermissionDecision.deny.output)
        }, onGone: { _ in })
        holder.server = server
        try server.start()
        defer { server.stop() }
        let content = String(repeating: "linha de código\n", count: 40_000)
        let input = JSONValue.object([
            JSONMember("hook_event_name", .string("PermissionRequest")),
            JSONMember("tool_name", .string("Write")),
            JSONMember("tool_input", .object([JSONMember("file_path", .string("/tmp/a.txt")), JSONMember("content", .string(content))])),
        ]).printed()
        let result = try await runHook(installer.script, input: input)
        #expect(result.output == String(decoding: ClaudePermissionDecision.deny.output, as: UTF8.self))
        let received = box.lock.withLock { box.requests.first?.1 }
        #expect(received?.count == input.utf8.count)
    }

    private final class ServerHolder: @unchecked Sendable {
        var server: HookSocketServer?
    }
}
