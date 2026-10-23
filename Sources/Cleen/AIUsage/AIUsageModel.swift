import CleenKit
import Foundation
import Observation

/// AI tool usage read from what's already on the Mac: Claude Code's transcripts for
/// tokens and cost, Claude Code's sign-in for the official limits, Codex's logs for its,
/// and the sign-ins Cursor, Copilot and Grok keep for theirs.
@Observable
final class AIUsageModel {
    private(set) var summary: UsageSummary?
    private(set) var claude: ClaudeLimits.Report?
    private(set) var claudeProblem: ClaudeLimits.Failure?
    private(set) var codex: [UsageWindow]?
    /// Cursor, Copilot and Grok, each only when it's set up on this Mac.
    private(set) var providers: [ProviderLimits] = []
    private(set) var isLoading = false
    private(set) var hasClaudeCode = true

    @ObservationIgnored private let reader = ClaudeLogReader()
    @ObservationIgnored private var lastLimitsCheck = Date.distantPast
    @ObservationIgnored private var lastProvidersCheck = Date.distantPast

    /// A provider's windows named after their tool (`Cursor · Mensal`), for views that
    /// list windows from several tools side by side.
    func providerWindows(of limits: ProviderLimits) -> [UsageWindow] {
        guard case .windows(let windows) = limits.state else { return [] }
        return windows.map { UsageWindow(name: "\(limits.provider.name) · \($0.name)", used: $0.used, resetsAt: $0.resetsAt, length: $0.length) }
    }

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

        // Cursor, Copilot and Grok are network calls too, on the same few-minute rhythm.
        if force || Date.now.timeIntervalSince(lastProvidersCheck) > 180 {
            lastProvidersCheck = .now
            providers = await ProviderLimits.fetchAll()
        }

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
