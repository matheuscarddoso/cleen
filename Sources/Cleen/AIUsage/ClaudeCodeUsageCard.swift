import CleenKit
import SwiftUI

/// Today's tokens and the last two weeks as small bars.
struct ClaudeCodeUsageCard: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        AIUsageCard(title: "Claude Code", symbol: "terminal") {
            if let summary = model.summary {
                HStack {
                    Text("Tokens hoje")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(summary.todayTokens.tokens)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                HStack {
                    Text("Média por dia")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text((summary.monthCost / 30).dollars)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                HStack {
                    Text("Sessão (5h)")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(summary.blockCost.dollars)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                Spacer(minLength: 0)
                Text("Tendência de uso")
                    .font(.system(size: 9.5))
                    .foregroundStyle(NotchStyle.tertiary)
                UsageTrend(days: summary.days)
                    .frame(height: 30)
            } else {
                VStack(spacing: 6) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Lendo o histórico do Claude Code. Só demora na primeira vez.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(NotchStyle.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
