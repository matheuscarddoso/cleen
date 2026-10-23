import CleenKit
import SwiftUI

/// Fourteen thin bars, one per day, today brightest.
struct UsageTrend: View {
    let days: [UsageSummary.Day]
    var height = 16.0

    var body: some View {
        let peak = max(days.map(\.cost).max() ?? 1, 0.01)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 1)
                    .fill(NotchStyle.primary.opacity(day.id == days.last?.id ? 0.85 : 0.3))
                    .frame(height: max(1.5, height * day.cost / peak))
                    .help("\(day.day.formatted(.dateTime.day().month(.abbreviated).locale(.cleen))): \(day.cost.dollars)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
        .accessibilityLabel("Uso dos últimos 14 dias")
    }
}
