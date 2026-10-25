import CleenKit
import SwiftUI

/// Every AI limit at a glance: today's spend and the trend on the left, the limits with
/// their pace on the right (topped up with where the month's spend went).
struct NotchAIUsageTab: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        Group {
            if !model.hasClaudeCode && model.codex == nil && model.providers.isEmpty {
                NotchPrompt(
                    symbol: "chart.bar.xaxis",
                    color: ToolPalette.indigo,
                    title: String(localized: "Nenhuma ferramenta de IA encontrada"),
                    message: String(localized: "O Cleen lê o uso do Claude Code, Codex, Cursor, Copilot e Grok com o que eles já guardam no seu Mac."),
                    buttonTitle: String(localized: "Procurar de novo")
                ) { Task { await model.refresh(force: true) } }
            } else if let summary = model.summary {
                HStack(alignment: .top, spacing: 18) {
                    AISpendSummary(summary: summary)
                        .padding(.leading, 4)
                        .frame(width: 220)
                    Rectangle()
                        .fill(NotchStyle.separator)
                        .frame(width: 1)
                    let rows = limitRows
                    // Three blocks fit the default panel; more tools scroll.
                    NotchScroll {
                        NotchGroup {
                            ForEach(rows) { row in
                                LimitBlock(symbol: row.symbol, label: row.label, value: row.value, fraction: row.fraction, pace: row.pace, color: row.color, detail: row.detail)
                            }
                            if showsClaudeFallback {
                                LimitBlock(symbol: ClaudeLogo.symbolName, label: String(localized: "Sessão (5h)"), value: summary.blockCost.dollars, fraction: 0, detail: model.claudeProblem.map(Self.problemText))
                            }
                            // Fill up to three blocks with where the month's spend went.
                            ForEach(summary.models.prefix(max(0, 3 - rows.count - (showsClaudeFallback ? 1 : 0)))) { share in
                                let fraction = share.cost / max(summary.monthCost, 0.01)
                                LimitBlock(symbol: "cube", label: share.name, value: fraction.percent, fraction: fraction, detail: String(localized: "do gasto"), isShare: true)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            } else {
                NotchScanning(title: String(localized: "Lendo o histórico do Claude Code"), detail: String(localized: "Só demora na primeira vez"))
            }
        }
        .task { await model.watch() }
    }

    /// The session spent so far, standing in for Claude's limits until they load. Only
    /// with Claude Code on this Mac: a Codex-only setup has no Claude session to show.
    private var showsClaudeFallback: Bool {
        model.hasClaudeCode && model.shows(.claude) && model.claude == nil
    }

    private struct LimitRowData: Identifiable {
        var id: String { label }
        let symbol: String
        let label: String
        let value: String
        let fraction: Double
        let pace: Double?
        let detail: String
        let color: Color

        init(symbol: String, window: UsageWindow) {
            self.symbol = symbol
            label = window.name
            value = window.used.percent
            fraction = window.used
            pace = window.elapsed()
            detail = NotchAIUsageTab.detail(for: window)
            color = NotchAIUsageTab.color(for: window)
        }

        /// A tool whose stored sign-in ran out: an empty bar and what renews it.
        init(signInAgain provider: AIProvider) {
            symbol = provider.symbol
            label = provider.name
            value = "—"
            fraction = 0
            pace = nil
            detail = NotchAIUsageTab.signInText(provider)
            color = NotchStyle.tertiary
        }
    }

    /// Claude first, then Codex, then the other tools in a fixed order, each as found.
    private var limitRows: [LimitRowData] {
        let claude = (model.claude?.windows ?? []).prefix(3).map { LimitRowData(symbol: ClaudeLogo.symbolName, window: $0) }
        let codex = (model.codex ?? []).prefix(2).map { LimitRowData(symbol: "terminal", window: UsageWindow(name: "Codex · \($0.name)", used: $0.used, resetsAt: $0.resetsAt, length: $0.length)) }
        let others = model.providers.flatMap { limits -> [LimitRowData] in
            guard case .windows = limits.state else { return [LimitRowData(signInAgain: limits.provider)] }
            return model.providerWindows(of: limits).map { LimitRowData(symbol: limits.provider.symbol, window: $0) }
        }
        return claude + codex + others
    }

    /// "50 min · ritmo 32%": when it resets and where the current pace lands.
    static func detail(for window: UsageWindow) -> String {
        var parts: [String] = []
        if let reset = window.resetsAt { parts.append(countdown(to: reset)) }
        if let projected = window.projected() {
            parts.append(projected > 1 ? String(localized: "acaba antes") : String(localized: "ritmo \(projected.percent)"))
        }
        return parts.joined(separator: " · ")
    }

    static func color(for window: UsageWindow) -> Color {
        if let projected = window.projected(), projected > 1 { return NotchStyle.critical }
        if window.used >= 0.9 { return NotchStyle.critical }
        if window.used >= 0.75 { return NotchStyle.warning }
        return NotchStyle.primary
    }

    /// `57 min`, `3h 20min`, `2 dias`.
    static func countdown(to date: Date) -> String {
        let seconds = max(0, date.timeIntervalSinceNow)
        if seconds >= 86_400 {
            let days = Int((seconds / 86_400).rounded())
            return days == 1 ? String(localized: "1 dia") : String(localized: "\(days) dias")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return String(localized: "\(max(1, minutes)) min") }
        return minutes % 60 == 0 ? String(localized: "\(minutes / 60)h") : String(localized: "\(minutes / 60)h \(minutes % 60)min")
    }

    static func problemText(_ failure: ClaudeLimits.Failure) -> String {
        switch failure {
        case .noCredential: String(localized: "entre no Claude Code")
        case .expired: String(localized: "abra o Claude Code")
        case .unavailable: String(localized: "limites indisponíveis")
        }
    }

    /// Cleen never renews another tool's sign-in; the tool does when it runs.
    static func signInText(_ provider: AIProvider) -> String {
        switch provider {
        case .cursor: String(localized: "abra o Cursor")
        case .copilot: String(localized: "entre de novo no Copilot")
        case .grok: String(localized: "abra o Grok CLI")
        }
    }
}
