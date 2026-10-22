import CleenKit
import SwiftUI

/// Every AI limit at a glance, as in OmniNotch: spend on top, one card per tool.
struct NotchAIUsageTab: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let summary = model.summary {
                    SpendLabel(title: "Hoje", value: summary.todayCost.dollars)
                    SpendLabel(title: "30 dias", value: summary.monthCost.dollars)
                    Text("em preço de API")
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.tertiary)
                }
                Spacer()
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
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ClaudeLimitsCard()
                    if let codex = model.codex {
                        LimitsCard(title: "Codex", symbol: "terminal", badge: nil, windows: codex)
                    }
                    ClaudeCodeUsageCard()
                    if model.codex == nil {
                        ModelSharesCard()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task { await model.watch() }
    }
}
