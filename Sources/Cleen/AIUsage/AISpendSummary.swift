import CleenKit
import SwiftUI

/// Today's spend as the headline in a light, large figure (like the disk on Visão
/// geral), the month under it, and the last two weeks as bars.
struct AISpendSummary: View {
    @Environment(AIUsageModel.self) private var model
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("Hoje")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                Spacer()
                if let plan = model.claude?.plan {
                    Text("Claude \(plan)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                NotchIconButton(symbol: "arrow.clockwise", help: String(localized: "Atualizar")) {
                    Task { await model.refresh(force: true) }
                }
                .rotationEffect(.degrees(model.isLoading ? 360 : 0))
                .animation(model.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isLoading)
            }
            .frame(height: 18)
            Text(summary.todayCost.dollars)
                .font(.system(size: 30, weight: .light).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text("\(summary.monthCost.dollars) em 30 dias · preço de API")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 6)
            UsageTrend(days: summary.days, height: 26)
            HStack {
                Text("14 dias")
                Spacer()
                Text("\((summary.monthCost / 30).dollars)/dia")
                    .monospacedDigit()
            }
            .font(.system(size: 10))
            .foregroundStyle(NotchStyle.tertiary)
        }
    }
}
