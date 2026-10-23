import CleenKit
import SwiftUI

/// Every AI limit at a glance: today's spend and the trend on the left, the limits with
/// their pace on the right (topped up with where the month's spend went).
struct NotchAIUsageTab: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        Group {
            if !model.hasClaudeCode && model.codex == nil {
                NotchPrompt(
                    symbol: "chart.bar.xaxis",
                    color: ToolPalette.indigo,
                    title: "Nenhuma ferramenta de IA encontrada",
                    message: "O Cleen lê o uso do Claude Code e do Codex direto dos arquivos deles no seu Mac.",
                    buttonTitle: "Procurar de novo"
                ) { Task { await model.refresh(force: true) } }
            } else if let summary = model.summary {
                HStack(alignment: .top, spacing: 18) {
                    AISpendSummary(summary: summary)
                        .padding(.leading, 4)
                        .frame(width: 220)
                    Rectangle()
                        .fill(NotchStyle.separator)
                        .frame(width: 1)
                    NotchGroup {
                        ForEach(limitRows.prefix(3)) { row in
                            LimitBlock(symbol: row.symbol, label: row.label, value: row.window.used.percent, fraction: row.window.used, pace: row.window.elapsed(), color: row.color, detail: row.detail)
                        }
                        if model.claude == nil {
                            LimitBlock(symbol: "asterisk", label: "Sessão (5h)", value: summary.blockCost.dollars, fraction: 0, detail: model.claudeProblem.map(Self.problemText))
                        }
                        // Fill up to three blocks with where the month's spend went.
                        ForEach(summary.models.prefix(max(0, 3 - min(limitRows.count, 3) - (model.claude == nil ? 1 : 0)))) { share in
                            let fraction = share.cost / max(summary.monthCost, 0.01)
                            LimitBlock(symbol: "cube", label: share.name, value: fraction.percent, fraction: fraction, detail: "do gasto", isShare: true)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(.bottom, 4)
            } else {
                NotchScanning(title: "Lendo o histórico do Claude Code", detail: "Só demora na primeira vez")
            }
        }
        .task { await model.watch() }
    }

    private struct LimitRowData: Identifiable {
        var id: String { label }
        let symbol: String
        let label: String
        let window: UsageWindow
        let detail: String
        let color: Color
    }

    private var limitRows: [LimitRowData] {
        let claude = (model.claude?.windows ?? []).prefix(3).map { ("asterisk", $0) }
        let codex = (model.codex ?? []).prefix(2).map { ("terminal", UsageWindow(name: "Codex · \($0.name)", used: $0.used, resetsAt: $0.resetsAt, length: $0.length)) }
        return (claude + codex).map { symbol, window in
            LimitRowData(symbol: symbol, label: window.name, window: window, detail: Self.detail(for: window), color: Self.color(for: window))
        }
    }

    /// "50 min · ritmo 32%": when it resets and where the current pace lands.
    static func detail(for window: UsageWindow) -> String {
        var parts: [String] = []
        if let reset = window.resetsAt { parts.append(countdown(to: reset)) }
        if let projected = window.projected() {
            parts.append(projected > 1 ? "acaba antes" : "ritmo \(projected.percent)")
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
            return days == 1 ? "1 dia" : "\(days) dias"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(max(1, minutes)) min" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)min"
    }

    static func problemText(_ failure: ClaudeLimits.Failure) -> String {
        switch failure {
        case .noCredential: "entre no Claude Code"
        case .expired: "abra o Claude Code"
        case .unavailable: "limites indisponíveis"
        }
    }
}
