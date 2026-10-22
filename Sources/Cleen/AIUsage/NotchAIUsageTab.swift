import CleenKit
import SwiftUI

/// Every AI limit at a glance: spend on top, then one grouped list — limits with their
/// pace, where the month's spend went, and the last two weeks.
struct NotchAIUsageTab: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let summary = model.summary {
                    SpendLabel(title: "Hoje", value: summary.todayCost.dollars)
                    SpendLabel(title: "30 dias", value: summary.monthCost.dollars)
                    Text("em preço de API")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                Spacer()
                if let plan = model.claude?.plan {
                    Text("Claude \(plan)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NotchStyle.secondary)
                }
                NotchIconButton(symbol: "arrow.clockwise", help: "Atualizar") {
                    Task { await model.refresh(force: true) }
                }
                .rotationEffect(.degrees(model.isLoading ? 360 : 0))
                .animation(model.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isLoading)
            }
            if !model.hasClaudeCode && model.codex == nil {
                NotchPrompt(
                    symbol: "chart.bar.xaxis",
                    color: ToolPalette.indigo,
                    title: "Nenhuma ferramenta de IA encontrada",
                    message: "O Cleen lê o uso do Claude Code e do Codex direto dos arquivos deles no seu Mac.",
                    buttonTitle: "Procurar de novo"
                ) { Task { await model.refresh(force: true) } }
            } else if let summary = model.summary {
                NotchGroup {
                    ForEach(limitRows) { row in
                        NotchMeterRow(symbol: row.symbol, label: row.label, value: row.window.used.percent, valueColor: row.color, detail: row.detail) {
                            ZStack {
                                UsageBar(fraction: row.window.used, height: 3.5, tint: row.color == NotchStyle.primary ? nil : row.color)
                                if let pace = row.window.elapsed() {
                                    PaceTick(fraction: pace)
                                }
                            }
                        }
                    }
                    if model.claude == nil {
                        NotchMeterRow(symbol: "asterisk", label: "Sessão (5h)", value: summary.blockCost.dollars, detail: model.claudeProblem.map(Self.problemText)) {
                            Color.clear
                        }
                    }
                    // Fill what's left of five rows with the biggest models.
                    ForEach(summary.models.prefix(max(0, 5 - limitRows.count - 1 - (model.claude == nil ? 1 : 0)))) { share in
                        NotchMeterRow(symbol: "cube", label: share.name, value: (share.cost / max(summary.monthCost, 0.01)).percent, detail: "do gasto") {
                            UsageBar(fraction: share.cost / max(summary.monthCost, 0.01), height: 3.5, tint: NotchStyle.barFill)
                        }
                    }
                    NotchMeterRow(symbol: "chart.bar", label: "Tendência", value: "\((summary.monthCost / 30).dollars)/dia") {
                        UsageTrend(days: summary.days)
                            .frame(height: 16)
                    }
                }
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
