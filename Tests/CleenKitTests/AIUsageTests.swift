import Foundation
import Testing
@testable import CleenKit

struct AIUsageTests {
    private func line(id: String, request: String, model: String = "claude-opus-5-5", at stamp: String, output: Int = 100) -> String {
        """
        {"timestamp":"\(stamp)","requestId":"\(request)","message":{"id":"\(id)","model":"\(model)","usage":{"input_tokens":10,"cache_creation_input_tokens":1000,"cache_read_input_tokens":2000,"output_tokens":\(output)}}}
        """
    }

    @Test func readsDeduplicatesAndPrices() throws {
        let sandbox = try Sandbox()
        let now = Date.now.formatted(.iso8601)
        let text = [
            line(id: "m1", request: "r1", at: now),
            line(id: "m1", request: "r1", at: now),            // same response, second content block
            #"{"type":"user","message":{"role":"user","content":"hi"}}"#,
            line(id: "m2", request: "r2", model: "claude-sonnet-5-5", at: now, output: 50),
        ].joined(separator: "\n") + "\n"
        try sandbox.file("projects/a/session.jsonl", bytes: 0)
        try text.write(to: sandbox.url("projects/a/session.jsonl"), atomically: true, encoding: .utf8)

        let reader = ClaudeLogReader(root: sandbox.url("projects"), cacheURL: nil)
        let entries = reader.read()
        #expect(entries.count == 2)

        let opus = try #require(entries.first { $0.model == "claude-opus-5-5" })
        // 10×4 + 100×20 + 1000×5 + 2000×0.2 per million
        #expect(abs(opus.cost - (40 + 2000 + 5000 + 400) / 1_000_000) < 1e-12)
    }

    @Test func onlyNewBytesAreReadAfterAppend() throws {
        let sandbox = try Sandbox()
        let now = Date.now.formatted(.iso8601)
        let path = sandbox.url("projects/a/s.jsonl")
        try sandbox.file("projects/a/s.jsonl", bytes: 0)
        try (line(id: "m1", request: "r1", at: now) + "\n").write(to: path, atomically: true, encoding: .utf8)
        let reader = ClaudeLogReader(root: sandbox.url("projects"), cacheURL: nil)
        #expect(reader.read().count == 1)

        let handle = try FileHandle(forWritingTo: path)
        try handle.seekToEnd()
        // A complete line plus half of one still being written.
        try handle.write(contentsOf: Data((line(id: "m2", request: "r2", at: now) + "\n{\"partial\":").utf8))
        try handle.close()
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(5)], ofItemAtPath: path.path(percentEncoded: false))
        #expect(reader.read().count == 2)
    }

    @Test func currentBlockIsTheOpenFiveHourWindow() {
        let now = Date.now
        func entry(_ minutesAgo: Double) -> UsageEntry {
            UsageEntry(timestamp: now.addingTimeInterval(-minutesAgo * 60), model: "claude-opus-5-5", input: 1, output: 1, cacheWrite: 0, cacheRead: 0, key: "\(minutesAgo)")
        }
        let old = entry(60 * 9)
        let recent = [entry(90), entry(30)]
        let block = UsageSummary.currentBlock([old] + recent, now: now)
        #expect(block.count == 2)
    }

    @Test(arguments: [("claude-opus-5-5", "Opus 5.5"), ("claude-sonnet-4-6-20260101", "Sonnet 4.6"), ("claude-haiku-5-5", "Haiku 5.5")])
    func modelFamilies(model: String, family: String) {
        #expect(UsageSummary.family(of: model) == family)
    }

    @Test func limitWindowsParseInOrder() throws {
        let json = """
        {"seven_day":{"utilization":67.0,"resets_at":"2026-10-30T12:50:00Z"},"five_hour":{"utilization":42.5,"resets_at":"2026-10-22T20:00:00Z"},"seven_day_opus":null}
        """
        let windows = try #require(ClaudeLimits.parseWindows(Data(json.utf8)))
        #expect(windows.map(\.name) == ["Sessão", "Semanal"])
        #expect(windows[0].used == 0.425)
        #expect(windows[0].resetsAt != nil)
    }

    @Test func credentialAndPlan() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"tok","expiresAt":4102444800000,"subscriptionType":"max","rateLimitTier":"default_claude_max_20x"}}"#
        let credential = try #require(ClaudeLimits.parseCredential(Data(json.utf8)))
        #expect(credential.accessToken == "tok")
        #expect(credential.plan == "Max 20x")
    }

    @Test func codexRateLimits() throws {
        let json = #"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":78.0,"window_minutes":300,"resets_in_seconds":3600},"secondary":{"used_percent":34.0,"window_minutes":10080,"resets_in_seconds":86400}}}}"#
        let windows = try #require(CodexLimits.parse(line: Data(json.utf8), loggedAt: .now))
        #expect(windows.map(\.used) == [0.78, 0.34])
    }

    @Test func paceProjection() {
        let window = UsageWindow(name: "Sessão", used: 0.5, resetsAt: .now.addingTimeInterval(2.5 * 3600), length: 5 * 3600)
        #expect(abs((window.elapsed() ?? 0) - 0.5) < 0.01)
        #expect(abs((window.projected() ?? 0) - 1.0) < 0.03)
    }
}

@Suite(.enabled(if: ProcessInfo.processInfo.environment["CLEEN_PROBE"] != nil))
struct AIUsageProbe {
    @Test func realLogs() {
        let clock = ContinuousClock()
        let start = clock.now
        let reader = ClaudeLogReader(cacheURL: nil)
        let entries = reader.read()
        let first = clock.now - start
        let again = clock.now
        _ = reader.read()
        let summary = UsageSummary(entries: entries)
        print("PROBE entries=\(entries.count) first=\(first) second=\(clock.now - again) today=\(summary.todayCost) month=\(summary.monthCost) block=\(summary.blockCost) models=\(summary.models.map { "\($0.name):\(Int($0.cost))" })")
    }
}
