import Foundation
import Testing
@testable import CleenKit

struct ClaudeSessionTests {
    private func tail(_ lines: [String]) -> Data { Data(lines.joined(separator: "\n").utf8) }

    private let title = #"{"type":"ai-title","aiTitle":"Refatorar o checkout","sessionId":"s"}"#
    private let prompt = #"{"type":"user","isSidechain":false,"cwd":"/Users/x/Projects/loja","timestamp":"2026-10-23T15:00:00.000Z","message":{"role":"user","content":"faz o checkout"}}"#
    private let toolCall = #"{"type":"assistant","isSidechain":false,"cwd":"/Users/x/Projects/loja","timestamp":"2026-10-23T15:00:05.000Z","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Bash","input":{}}]}}"#
    private let toolResult = #"{"type":"user","isSidechain":false,"timestamp":"2026-10-23T15:00:09.000Z","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#
    private let done = #"{"type":"assistant","isSidechain":false,"timestamp":"2026-10-23T15:01:00.000Z","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"Pronto."}]}}"#
    private let sidechain = #"{"type":"assistant","isSidechain":true,"timestamp":"2026-10-23T15:02:00.000Z","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Read"}]}}"#
    private let bookkeeping = #"{"type":"attachment","timestamp":"2026-10-23T15:03:00.000Z"}"#

    @Test func runningToolWhileACallIsOut() throws {
        let session = try #require(ClaudeSessionParser.session(id: "s", tail: tail([title, prompt, toolCall, bookkeeping]), updatedAt: .now))
        #expect(session.state == .running(tool: "Bash"))
        #expect(session.title == "Refatorar o checkout")
        #expect(session.projectName == "loja")
    }

    @Test func thinkingAfterAToolResult() throws {
        let session = try #require(ClaudeSessionParser.session(id: "s", tail: tail([prompt, toolCall, toolResult]), updatedAt: .now))
        #expect(session.state == .thinking)
    }

    @Test func waitingOnceTheTurnEnds() throws {
        let session = try #require(ClaudeSessionParser.session(id: "s", tail: tail([prompt, toolCall, toolResult, done, sidechain, bookkeeping]), updatedAt: .now))
        #expect(session.state == .waiting)
        // No title yet: the folder names it.
        #expect(session.title == "loja")
    }

    @Test func noConversationNoSession() {
        #expect(ClaudeSessionParser.session(id: "s", tail: tail([title, bookkeeping]), updatedAt: .now) == nil)
    }

    @Test func scannerReadsOnlyRecentTranscripts() throws {
        let sandbox = try Sandbox()
        let fresh = try sandbox.file("projects/-loja/aaaa.jsonl")
        try tail([prompt, toolCall]).write(to: fresh)
        let old = try sandbox.file("projects/-velho/bbbb.jsonl")
        try tail([prompt, done]).write(to: old)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-7200)], ofItemAtPath: old.path(percentEncoded: false))

        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 1800).scan()
        #expect(sessions.map(\.id) == ["aaaa"])
    }

    /// The session's turn ended on "Waiting for 1 dynamic workflow", but its agent works on.
    @Test func backgroundAgentsKeepASessionBusy() throws {
        let sandbox = try Sandbox()
        let main = try sandbox.file("projects/-loja/aaaa.jsonl")
        try tail([prompt, done]).write(to: main)
        // The main file is old, past the window: the agent's fresh writes keep it listed.
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-3600)], ofItemAtPath: main.path(percentEncoded: false))
        let working = try sandbox.file("projects/-loja/aaaa/subagents/agent-1.jsonl")
        try tail([sidechain]).write(to: working)
        try Data(#"{"agentType":"general-purpose"}"#.utf8).write(to: sandbox.file("projects/-loja/aaaa/subagents/agent-1.meta.json"))
        // One said it finished, one ended its turn without saying: neither counts.
        try tail([sidechain]).write(to: sandbox.file("projects/-loja/aaaa/subagents/agent-2.jsonl"))
        try Data(#"{"finished":true}"#.utf8).write(to: sandbox.file("projects/-loja/aaaa/subagents/agent-2.meta.json"))
        let sidechainDone = done.replacing(#""isSidechain":false"#, with: #""isSidechain":true"#)
        try tail([sidechain, sidechainDone]).write(to: sandbox.file("projects/-loja/aaaa/subagents/agent-3.jsonl"))

        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 1800).scan()
        #expect(sessions.map(\.state) == [.delegating(agents: 1)])
        #expect(sessions.first?.state.isBusy == true)
    }
}

struct ClaudeActivityTests {
    private func object(_ json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]) ?? [:]
    }

    @Test func readsTheTurnsStepsWithTheirResults() throws {
        let lines = [
            #"{"type":"user","timestamp":"2026-10-23T15:00:00.000Z","message":{"role":"user","content":"conserta o total"}}"#,
            #"{"type":"assistant","timestamp":"2026-10-23T15:00:01.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Tracing where the cart total goes stale. Then fix."},{"type":"tool_use","id":"a","name":"Read","input":{"file_path":"/p/CartStore.swift"}}]}}"#,
            #"{"type":"user","timestamp":"2026-10-23T15:00:02.000Z","toolUseResult":{"type":"text","file":{"filePath":"/p/CartStore.swift","numLines":212}},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"a","content":"…"}]}}"#,
            #"{"type":"assistant","timestamp":"2026-10-23T15:00:03.000Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"b","name":"Edit","input":{"file_path":"/p/CartStore.swift","old_string":"a\nb","new_string":"c"}}]}}"#,
            #"{"type":"user","timestamp":"2026-10-23T15:00:04.000Z","toolUseResult":{"structuredPatch":[{"lines":["-a","-b","+c","+d"," e"]}]},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"b","content":"ok"}]}}"#,
            #"{"type":"assistant","timestamp":"2026-10-23T15:00:05.000Z","message":{"role":"assistant","content":[{"type":"tool_use","id":"c","name":"Bash","input":{"command":"swift build","description":"Build"}}]}}"#,
        ]
        let activity = ClaudeActivity.read(lines.map(object))
        #expect(activity.steps.map(\.id) == ["a", "b", "c"])
        #expect(activity.steps[0].kind == .read(file: "/p/CartStore.swift", lines: 212) && activity.steps[0].isDone)
        #expect(activity.steps[1].kind == .edit(file: "/p/CartStore.swift", added: 2, removed: 2))
        #expect(activity.steps[2].kind == .command("swift build", description: "Build") && !activity.steps[2].isDone)
        #expect(activity.note == "Tracing where the cart total goes stale.")
    }

    @Test func aNewPromptStartsANewTurn() {
        let lines = [
            #"{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a","name":"Read","input":{"file_path":"/x"}}]}}"#,
            #"{"type":"user","message":{"role":"user","content":"outra coisa"}}"#,
        ]
        #expect(ClaudeActivity.read(lines.map(object)).steps.isEmpty)
    }
}
