import CleenKit
import SwiftUI

/// Claude's official limits when they can be read; otherwise the current five-hour
/// window computed from local usage, and why the official numbers are missing.
struct ClaudeLimitsCard: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        if let report = model.claude {
            LimitsCard(title: "Claude", symbol: "asterisk", badge: report.plan, windows: report.windows)
        } else {
            AIUsageCard(title: "Claude", symbol: "asterisk") {
                if let summary = model.summary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sessão atual (5h)")
                            .font(.system(size: 11, weight: .medium))
                        Text(summary.blockStart == nil ? "Nenhuma sessão aberta" : "\(summary.blockCost.dollars) · \(summary.blockTokens.tokens) tokens")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        if let start = summary.blockStart {
                            Text("Reinicia \(start.addingTimeInterval(5 * 3600).formatted(.relative(presentation: .named, unitsStyle: .abbreviated).locale(.cleen)))")
                                .font(.system(size: 9.5))
                                .foregroundStyle(NotchStyle.tertiary)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text(problemText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(NotchStyle.warning.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var problemText: String {
        switch model.claudeProblem {
        case .noCredential: "Faça login no Claude Code para ver os limites oficiais."
        case .expired: "Abra o Claude Code uma vez para renovar o acesso aos limites."
        case .unavailable: "Os limites oficiais não responderam agora."
        case nil: "Lendo os limites…"
        }
    }
}
