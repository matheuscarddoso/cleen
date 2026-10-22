import Charts
import SwiftUI

/// A tiny area chart of recent samples, oldest on the left.
struct Sparkline: View {
    let values: [Double]
    var tint = NotchStyle.primary
    /// Fixed top of the scale; nil scales to the data (for throughput).
    var maximum: Double?

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            AreaMark(x: .value("t", index), y: .value("v", value))
                .foregroundStyle(
                    LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.monotone)
            LineMark(x: .value("t", index), y: .value("v", value))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.25))
                .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...max(1, Self.capacity - 1))
        .chartYScale(domain: 0...yMaximum)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }

    static let capacity = 60

    private var yMaximum: Double {
        if let maximum { return maximum }
        return max(values.max() ?? 1, 1) * 1.15
    }
}
