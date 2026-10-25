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
    /// The tools switched off in Ajustes › Uso de IA: not read, not shown.
    private(set) var hidden = AITool.hiddenTools()

    @ObservationIgnored private let reader = ClaudeLogReader()
    @ObservationIgnored private var lastLimitsCheck = Date.distantPast
    @ObservationIgnored private var lastProvidersCheck = Date.distantPast

    /// A provider's windows named after their tool (`Cursor · Mensal`), for views that
    /// list windows from several tools side by side.
    func providerWindows(of limits: ProviderLimits) -> [UsageWindow] {
        guard case .windows(let windows) = limits.state else { return [] }
        return windows.map { UsageWindow(name: "\(limits.provider.name) · \($0.name)", used: $0.used, resetsAt: $0.resetsAt, length: $0.length) }
    }

    func shows(_ tool: AITool) -> Bool { !hidden.contains(tool) }

    func setShows(_ tool: AITool, _ shows: Bool) {
        UserDefaults.standard.set(shows, forKey: tool.storageKey)
        if shows {
            hidden.remove(tool)
            Task { await refresh(force: true) }
            return
        }
        hidden.insert(tool)
        switch tool {
        case .claude:
            claude = nil
            claudeProblem = nil
        case .codex:
            codex = nil
        case .cursor, .copilot, .grok:
            providers.removeAll { AITool($0.provider) == tool }
        }
    }

    /// Whether the tool is set up on this Mac, as far as the last refresh could tell.
    func isFound(_ tool: AITool) -> Bool {
        switch tool {
        case .claude: hasClaudeCode
        case .codex: codex != nil || FileManager.default.fileExists(atPath: Paths.home.appending(path: ".codex").path(percentEncoded: false))
        case .cursor, .copilot, .grok: providers.contains { AITool($0.provider) == tool }
        }
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
        codex = shows(.codex) ? await offMain { CodexLimits.read() } : nil

        // Cursor, Copilot and Grok are network calls too, on the same few-minute rhythm.
        if force || Date.now.timeIntervalSince(lastProvidersCheck) > 180 {
            lastProvidersCheck = .now
            let hidden = hidden
            providers = await ProviderLimits.fetchAll().filter { !hidden.contains(AITool($0.provider)) }
        }

        // The limits endpoint is a network call; every few minutes is plenty.
        // Without a sign-in to read (or with the Keychain prompt turned down) it waits for
        // the refresh button or half an hour, so a "Deny" isn't asked again every few minutes.
        let interval: TimeInterval = claudeProblem == .noCredential ? 1800 : 180
        guard hasClaudeCode, shows(.claude), force || Date.now.timeIntervalSince(lastLimitsCheck) > interval else { return }
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
