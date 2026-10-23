import CleenKit
import Foundation
import Observation

/// AI tool usage read from what's already on the Mac: Claude Code's transcripts for
/// tokens and cost, Claude Code's sign-in for the official limits, Codex's logs for its.
@Observable
final class AIUsageModel {
    private(set) var summary: UsageSummary?
    private(set) var claude: ClaudeLimits.Report?
    private(set) var claudeProblem: ClaudeLimits.Failure?
    private(set) var codex: [UsageWindow]?
    private(set) var isLoading = false
    private(set) var hasClaudeCode = true

    @ObservationIgnored private let reader = ClaudeLogReader()
    @ObservationIgnored private var lastLimitsCheck = Date.distantPast

    /// Refreshes now and every minute while the tab is on screen.
    func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let reader = reader
        hasClaudeCode = reader.isInstalled
        summary = await offMain { UsageSummary(entries: reader.read()) }
        codex = await offMain { CodexLimits.read() }

        // The limits endpoint is a network call; every few minutes is plenty.
        // Without a sign-in to read (or with the Keychain prompt turned down) it waits for
        // the refresh button, so a "Deny" isn't asked again every few minutes.
        let interval: TimeInterval = claudeProblem == .noCredential ? .infinity : 180
        guard hasClaudeCode, force || Date.now.timeIntervalSince(lastLimitsCheck) > interval else { return }
        lastLimitsCheck = .now
        switch await ClaudeLimits.fetch() {
        case .success(let report):
            claude = report
            claudeProblem = nil
        case .failure(let failure):
            claudeProblem = failure
        }
    }
}
