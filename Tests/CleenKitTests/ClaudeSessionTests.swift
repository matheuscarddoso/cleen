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
        #expect(sessions.map(\.state) == [.delegating(agents: 1, workflows: 0)])
        #expect(sessions.first?.state.isBusy == true)
    }
}

/// Lines that aren't the person prompting, and the states that hand the turn back.
struct ClaudeSessionStateTests {
    private func tail(_ lines: [String]) -> Data { Data(lines.joined(separator: "\n").utf8) }
    private func state(_ lines: [String]) -> ClaudeSession.State? {
        ClaudeSessionParser.session(id: "s", tail: tail(lines), updatedAt: .now)?.state
    }

    private let prompt = #"{"type":"user","isSidechain":false,"cwd":"/p/loja","timestamp":"2026-10-23T15:00:00.000Z","message":{"role":"user","content":"faz o checkout"}}"#
    private let toolCall = #"{"type":"assistant","isSidechain":false,"timestamp":"2026-10-23T15:00:05.000Z","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}"#
    private let done = #"{"type":"assistant","isSidechain":false,"timestamp":"2026-10-23T15:01:00.000Z","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"Pronto."}]}}"#
    private let turnDuration = #"{"type":"system","subtype":"turn_duration","isSidechain":false,"timestamp":"2026-10-23T15:01:01.000Z"}"#

    private func tool(_ name: String) -> String {
        #"{"type":"assistant","isSidechain":false,"timestamp":"2026-10-23T15:00:05.000Z","message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","id":"q","name":"\#(name)","input":{}}]}}"#
    }

    @Test func anInterruptionHandsTheTurnBack() {
        let plain = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
        let forTool = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"[Request interrupted by user for tool use]"}}"#
        #expect(state([prompt, toolCall, plain]) == .interrupted)
        // Claude Code closes the interrupted turn with its duration: still an interruption.
        #expect(state([prompt, toolCall, forTool, turnDuration]) == .interrupted)
        #expect(ClaudeSession.State.interrupted.isBusy == false)
        #expect(ClaudeSession.State.interrupted.callsForThePerson == false)
    }

    @Test func localCommandsAfterTheTurnLeaveItWaiting() {
        let command = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<command-name>/model</command-name>\n            <command-message>model</command-message>"}}"#
        let stdout = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<local-command-stdout>Set model to Opus</local-command-stdout>"}}"#
        let caveat = #"{"type":"user","isSidechain":false,"isMeta":true,"message":{"role":"user","content":"<local-command-caveat>Caveat: the messages below were generated by the user while running local commands.</local-command-caveat>"}}"#
        let system = #"{"type":"system","subtype":"local_command","isSidechain":false,"content":"<local-command-stdout></local-command-stdout>"}"#
        let shell = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<bash-input>ls</bash-input>"}}"#
        let away = #"{"type":"system","subtype":"away_summary","isSidechain":false,"content":"While you were away"}"#
        #expect(state([prompt, done, turnDuration, command, stdout, caveat, system, shell, away]) == .waiting)
    }

    @Test func aSkillRunAsASlashCommandIsAPrompt() {
        let skill = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<command-message>humanizer</command-message>\n<command-name>/humanizer</command-name>"}}"#
        #expect(state([prompt, done, skill]) == .thinking)
    }

    @Test func metaAndCompactionLinesAreIgnored() {
        let meta = #"{"type":"user","isSidechain":false,"isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Base directory for this skill"}]}}"#
        let summary = #"{"type":"user","isSidechain":false,"isCompactSummary":true,"message":{"role":"user","content":"This session is being continued from a previous conversation. Compacted while idle."}}"#
        let boundary = #"{"type":"system","subtype":"compact_boundary","isSidechain":false,"content":"Conversation compacted"}"#
        #expect(state([prompt, done, boundary, summary, meta]) == .waiting)
    }

    @Test func aTaskNotificationResumesTheTurn() {
        let notification = #"{"type":"user","isSidechain":false,"origin":{"kind":"task-notification"},"message":{"role":"user","content":"<task-notification>\n<task-id>a1</task-id>\n</task-notification>"}}"#
        #expect(state([prompt, done, turnDuration, notification]) == .thinking)
    }

    /// Claude Code 2.1 records these without handing them to the model: nothing answers.
    @Test func aTranscriptOnlyNotificationLeavesTheTurnOver() {
        let delivered = #"{"type":"user","isSidechain":false,"timestamp":"2026-11-02T02:21:17.505Z","origin":{"kind":"task-notification","producer":"session-task"},"promptSource":"system","queueSkipAttachments":true,"queueTranscriptOnly":true,"message":{"role":"user","content":"<task-notification>\n<task-id>af33c02006b4c3681</task-id>\n<status>completed</status>\n<summary>Agent \"implement:agents\" finished</summary>\n<result>This agent's report was delivered to you as a message from \"af33c02006b4c3681\" (its SubagentHandback call). Read it there; it is not repeated here.\n</result>\n</task-notification>"}}"#
        let leftBehind = #"{"type":"user","isSidechain":false,"origin":{"kind":"task-notification"},"queueTranscriptOnly":true,"message":{"role":"user","content":"<task-notification>\n<task-id>byqdd7mc4</task-id>\n<task-id>__orphan_summary__:shell</task-id>\n<status>stopped</status>\n<summary>2 background shell command tasks didn't finish before the previous session ended. Task ids: byqdd7mc4, bqhe7etk6.</summary>\n</task-notification>"}}"#
        let meta = #"{"type":"user","isSidechain":false,"isMeta":true,"message":{"role":"user","content":"<system-reminder>\n<tools-used-before-summary>SubagentHandback</tools-used-before-summary>\n</system-reminder>"}}"#
        #expect(state([prompt, done, turnDuration, meta, delivered]) == .waiting)
        #expect(state([prompt, done, turnDuration, leftBehind]) == .waiting)
    }

    /// A manual /compact as Claude Code writes it: the bare command first, then the
    /// boundary, the summary, the caveat and the command's echo. No turn_duration follows.
    @Test func aManualCompactionLeavesTheTurnOver() {
        let command = #"{"type":"user","isSidechain":false,"timestamp":"2026-10-16T20:27:58.766Z","message":{"role":"user","content":"/compact"}}"#
        let boundary = #"{"type":"system","subtype":"compact_boundary","isSidechain":false,"compactMetadata":{"trigger":"manual","preTokens":833557}}"#
        let summary = #"{"type":"user","isSidechain":false,"isCompactSummary":true,"message":{"role":"user","content":"This session is being continued from a previous conversation that ran out of context."}}"#
        let caveat = #"{"type":"user","isSidechain":false,"isMeta":true,"message":{"role":"user","content":"<local-command-caveat>The command below was run directly in Claude Code, not sent to you.</local-command-caveat>"}}"#
        let echo = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<command-name>/compact</command-name>\n            <command-message>compact</command-message>"}}"#
        let stdout = #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"<local-command-stdout>\u001b[2mCompacted (ctrl+o to see full summary)\u001b[22m</local-command-stdout>"}}"#
        #expect(state([prompt, done, turnDuration, command, boundary, summary, caveat, echo, stdout]) == .waiting)
        // Mid-compaction, before anything else is written.
        #expect(state([prompt, done, turnDuration, command]) == .waiting)
    }

    @Test func onlyTheCompactCommandIsTakenForOne() {
        #expect(ClaudeSessionParser.isCompactCommand("/compact"))
        #expect(ClaudeSessionParser.isCompactCommand("/compact keep the API decisions"))
        #expect(!ClaudeSessionParser.isCompactCommand("/compacting"))
        #expect(!ClaudeSessionParser.isCompactCommand("/Users/x/compact"))
        #expect(!ClaudeSessionParser.isCompactCommand("faz o /compact depois"))
    }

    @Test func aQuestionWaitsForAnAnswer() {
        let asking = state([prompt, tool("AskUserQuestion")])
        #expect(asking == .asking)
        #expect(asking?.isBusy == false)
        #expect(asking?.needsAnswer == true)
        #expect(asking?.callsForThePerson == true)
    }

    @Test func aPlanWaitsForReview() {
        #expect(state([prompt, tool("ExitPlanMode")]) == .reviewingPlan)
    }

    @Test func anAPIErrorStopsTheTurn() {
        let error = #"{"type":"assistant","isSidechain":false,"isApiErrorMessage":true,"message":{"role":"assistant","stop_reason":"stop_sequence","content":[{"type":"text","text":"API Error: 529 Overloaded"}]}}"#
        let note = #"{"type":"system","subtype":"informational","isSidechain":false,"content":"Usage limit reached"}"#
        #expect(state([prompt, toolCall, error, note, turnDuration]) == .failed)
    }

    @Test func aClosedTurnIsOverWhateverItsLastLineSaid() {
        let streaming = #"{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"Feito."}]}}"#
        #expect(state([prompt, streaming]) == .thinking)
        #expect(state([prompt, streaming, turnDuration]) == .waiting)
    }

    @Test func toolsReadAsWhatTheyDo() {
        #expect(ClaudeTool(name: "Bash") == .command)
        #expect(ClaudeTool(name: "MultiEdit") == .editing)
        #expect(ClaudeTool(name: "Glob") == .searching)
        #expect(ClaudeTool(name: "Workflow") == .workflow)
        #expect(ClaudeTool(name: "mcp__claude_ai_Notion__notion-search") == .mcp(server: "Notion"))
        #expect(ClaudeTool(name: "mcp__plugin_figma_figma__get_code") == .mcp(server: "Figma"))
        #expect(ClaudeTool(name: "mcp__claude_ai_Higgsfield_AI__balance") == .mcp(server: "Higgsfield AI"))
        #expect(ClaudeTool(name: "mcp__context7__resolve") == .mcp(server: "Context7"))
        #expect(ClaudeTool(name: "TodoWrite") == .other("TodoWrite"))
        #expect(ClaudeTool(name: "") == .other(""))
    }
}

/// Dynamic workflows, as Claude Code 2.1 lays them out next to the session's transcript.
struct ClaudeWorkflowScanTests {
    private func tail(_ lines: [String]) -> Data { Data(lines.joined(separator: "\n").utf8) }

    private let prompt = #"{"type":"user","isSidechain":false,"cwd":"/p/loja","timestamp":"2026-10-23T15:00:00.000Z","message":{"role":"user","content":"ultracode"}}"#
    /// The session's own turn ends as soon as the workflow is launched.
    private let waitingForWorkflow = #"{"type":"assistant","isSidechain":false,"timestamp":"2026-10-23T15:01:00.000Z","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"Waiting for the workflow."}]}}"#
    private let agentWorking = #"{"type":"assistant","isSidechain":true,"message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","name":"Edit"}]}}"#
    private let agentDone = #"{"type":"assistant","isSidechain":true,"message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"Feito."}]}}"#
    private let meta = #"{"agentType":"workflow-subagent","isBuiltIn":true,"description":"implement:agents","workflowPhase":"Implement","spawnDepth":1,"requestShape":"foreground"}"#
    private let journal = """
    {"type":"launched"}
    {"type":"started","key":"v2:a","agentId":"a1","label":"implement:agents","phase":"Implement"}
    {"type":"started","key":"v2:b","agentId":"a2","label":"implement:player","phase":"Implement"}
    """

    private func age(_ url: URL, _ seconds: TimeInterval) throws {
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-seconds)], ofItemAtPath: url.path(percentEncoded: false))
    }

    /// A session whose turn ended on launching run `wf_1`, with one agent still at work,
    /// one done, the journal, and the script folder Claude Code keeps in `workflows/`.
    private func workflowSession(in sandbox: Sandbox, agentAge: TimeInterval = 5) throws -> URL {
        let main = try sandbox.file("projects/-loja/aaaa.jsonl")
        try tail([prompt, waitingForWorkflow]).write(to: main)
        try age(main, 3600)
        let run = "projects/-loja/aaaa/subagents/workflows/wf_1"
        let working = try sandbox.file("\(run)/agent-a1.jsonl")
        try tail([agentWorking]).write(to: working)
        try Data(meta.utf8).write(to: sandbox.file("\(run)/agent-a1.meta.json"))
        let finished = try sandbox.file("\(run)/agent-a2.jsonl")
        try tail([agentWorking, agentDone]).write(to: finished)
        try Data(meta.utf8).write(to: sandbox.file("\(run)/agent-a2.meta.json"))
        let journalFile = try sandbox.file("\(run)/journal.jsonl")
        try Data(journal.utf8).write(to: journalFile)
        try sandbox.file("projects/-loja/aaaa/workflows/scripts/ultracode-wf_1.js")
        for file in try FileManager.default.contentsOfDirectory(at: sandbox.url(run), includingPropertiesForKeys: nil) {
            try age(file, agentAge)
        }
        return sandbox.url("projects/-loja/aaaa")
    }

    @Test func aRunningWorkflowKeepsTheSessionBusy() throws {
        let sandbox = try Sandbox()
        try workflowSession(in: sandbox)
        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 1800).scan()
        // One agent at work: the finished one and the journal don't count.
        #expect(sessions.map(\.state) == [.delegating(agents: 1, workflows: 1)])
        // The workflow's writes keep the session in the window though its own file is old.
        let updated = try #require(sessions.first?.updatedAt)
        #expect(Date.now.timeIntervalSince(updated) < 60)
    }

    @Test func aWorkflowBetweenAgentsStillCountsAsOne() throws {
        let sandbox = try Sandbox()
        try workflowSession(in: sandbox)
        let run = "projects/-loja/aaaa/subagents/workflows/wf_1"
        try tail([agentWorking, agentDone]).write(to: sandbox.url("\(run)/agent-a1.jsonl"))
        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 1800).scan()
        #expect(sessions.map(\.state) == [.delegating(agents: 1, workflows: 1)])
    }

    @Test func aRunningSnapshotDoesNotEndTheRun() throws {
        let sandbox = try Sandbox()
        let session = try workflowSession(in: sandbox)
        try Data(#"{"runId":"wf_1","status":"running","agentCount":2}"#.utf8).write(to: session.appending(path: "workflows/wf_1.json"))
        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 1800).scan()
        #expect(sessions.map(\.state) == [.delegating(agents: 1, workflows: 1)])
    }

    @Test func aTerminalSnapshotEndsTheRun() throws {
        for snapshot in [#"{"runId":"wf_1","status":"completed"}"#, #"{"runId":"wf_1","status":"killed"}"#, #"{"runId":"wf_1","error":"boom"}"#, #"{"runId":"wf_1"}"#] {
            let sandbox = try Sandbox()
            let session = try workflowSession(in: sandbox)
            try Data(snapshot.utf8).write(to: session.appending(path: "workflows/wf_1.json"))
            let work = ClaudeSessionScanner.backgroundWork(in: session, now: .now)
            #expect(work.workflows == 0 && work.agents == 0, "\(snapshot)")
        }
    }

    @Test func aStaleRunIsTakenAsGone() throws {
        let sandbox = try Sandbox()
        try workflowSession(in: sandbox, agentAge: ClaudeSessionScanner.agentActivity + 60)
        let sessions = ClaudeSessionScanner(root: sandbox.url("projects"), window: 3 * 3600).scan()
        #expect(sessions.map(\.state) == [.waiting])
    }

    @Test func aJournalThatEndedEndsTheRun() throws {
        let sandbox = try Sandbox()
        let session = try workflowSession(in: sandbox)
        try Data((journal + "\n" + #"{"type":"completed"}"#).utf8).write(to: session.appending(path: "subagents/workflows/wf_1/journal.jsonl"))
        #expect(ClaudeSessionScanner.backgroundWork(in: session, now: .now).workflows == 0)
    }

    /// Agents that hand their report back with a tool end on its result, not on end_turn.
    @Test func anAgentThatHandedBackIsDone() throws {
        let call = { (id: String, name: String) in
            #"{"type":"assistant","isSidechain":true,"message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","id":"\#(id)","name":"\#(name)","input":{}}]}}"#
        }
        let result = { (id: String) in
            #"{"type":"user","isSidechain":true,"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"\#(id)","content":"ok"}]}}"#
        }
        let attachment = #"{"type":"attachment","isSidechain":true}"#
        let sandbox = try Sandbox()
        let handedBack = try sandbox.file("handback.jsonl")
        try tail([call("b1", "Bash"), result("b1"), call("h1", "SubagentHandback"), attachment, result("h1")]).write(to: handedBack)
        let structured = try sandbox.file("structured.jsonl")
        try tail([call("s1", "StructuredOutput"), attachment, result("s1")]).write(to: structured)
        // Results for two calls at once, one of them the handback.
        let parallel = try sandbox.file("parallel.jsonl")
        try tail([call("r1", "Read"), call("h2", "SubagentHandback"), result("r1"), result("h2")]).write(to: parallel)
        // The report rides in the call: a long one puts it past the usual tail.
        let report = String(repeating: "Relatório. ", count: 12_000)
        let longReport = #"{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"tool_use","id":"h3","name":"SubagentHandback","input":{"message":"\#(report)"}}]}}"#
        let long = try sandbox.file("long.jsonl")
        try tail([call("b3", "Bash"), result("b3"), longReport, attachment, result("h3")]).write(to: long)
        let stillWorking = try sandbox.file("working.jsonl")
        try tail([call("h0", "SubagentHandback"), result("h0"), call("b2", "Bash"), result("b2")]).write(to: stillWorking)

        #expect(ClaudeSessionScanner.endedItsTurn(handedBack))
        #expect(ClaudeSessionScanner.endedItsTurn(structured))
        #expect(ClaudeSessionScanner.endedItsTurn(parallel))
        #expect(ClaudeSessionScanner.endedItsTurn(long))
        // A plain tool's result is the model's to answer: still at work.
        #expect(!ClaudeSessionScanner.endedItsTurn(stillWorking))
    }

    @Test func anAgentWithAResultInTheJournalIsDone() throws {
        let sandbox = try Sandbox()
        let session = try workflowSession(in: sandbox)
        let result = #"{"type":"result","key":"v2:a","agentId":"a1","result":{"findings":[]}}"#
        try Data((journal + "\n" + result).utf8).write(to: session.appending(path: "subagents/workflows/wf_1/journal.jsonl"))
        let journal = ClaudeSessionScanner.WorkflowJournal.read(session.appending(path: "subagents/workflows/wf_1/journal.jsonl"))
        #expect(journal == ClaudeSessionScanner.WorkflowJournal(ended: false, finishedAgents: ["a1"]))
        // a1 handed in its result and a2 ended its turn: the run is between phases, still one.
        let work = ClaudeSessionScanner.backgroundWork(in: session, now: .now)
        #expect(work.workflows == 1 && work.agents == 1)
        #expect(ClaudeSessionScanner.activeAgents(in: session.appending(path: "subagents/workflows/wf_1"), now: .now, finished: journal.finishedAgents).count == 0)
    }

    @Test func everyConfigFolderIsScannedAndSessionsDeduped() throws {
        let sandbox = try Sandbox()
        let done = waitingForWorkflow
        // The same session in two configs: the newer copy wins.
        let stale = try sandbox.file("home/.claude/projects/-loja/aaaa.jsonl")
        try tail([prompt, done]).write(to: stale)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-600)], ofItemAtPath: stale.path(percentEncoded: false))
        let fresh = try sandbox.file("home/.claude-three/projects/-loja/aaaa.jsonl")
        try tail([prompt]).write(to: fresh)
        try tail([prompt, done]).write(to: sandbox.file("home/.claude-work/projects/-site/bbbb.jsonl"))
        try tail([prompt, done]).write(to: sandbox.file("custom/projects/-api/cccc.jsonl"))
        // Files named like a config aren't one.
        try sandbox.file("home/.claude-buddy.json")

        let folders = ClaudeSessionScanner.projectFolders(home: sandbox.url("home"), configDir: sandbox.url("custom").path(percentEncoded: false))
        #expect(folders.map { $0.deletingLastPathComponent().lastPathComponent } == [".claude", ".claude-three", ".claude-work", "custom"])

        let scanner = ClaudeSessionScanner(roots: .discovered(home: sandbox.url("home"), configDir: sandbox.url("custom").path(percentEncoded: false)), window: 1800)
        let sessions = scanner.scan()
        #expect(sessions.map(\.id).sorted() == ["aaaa", "bbbb", "cccc"])
        #expect(sessions.first { $0.id == "aaaa" }?.state == .thinking)
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
