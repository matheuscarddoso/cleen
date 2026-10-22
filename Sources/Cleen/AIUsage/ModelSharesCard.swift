import CleenKit
import SwiftUI

/// Where the month's spend went, by model.
struct ModelSharesCard: View {
    @Environment(AIUsageModel.self) private var model

    var body: some View {
        AIUsageCard(title: "Modelos · 30 dias", symbol: "cube") {
            if let summary = model.summary {
                let total = max(summary.monthCost, 0.01)
                ForEach(summary.models.prefix(3)) { share in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(share.name)
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                            Text((share.cost / total).percent)
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        }
                        UsageBar(fraction: share.cost / total, height: 4, tint: .white)
                    }
                }
            }
        }
    }
}
