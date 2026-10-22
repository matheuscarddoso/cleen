import CleenKit
import SwiftUI

struct LiveCharts: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                LiveChartCard(
                    title: "CPU",
                    value: monitor.cpu?.total.percent ?? "—",
                    detail: monitor.cpu.map { "\($0.user.percent) apps · \($0.system.percent) sistema" } ?? "",
                    history: monitor.cpuHistory,
                    maximum: 1
                )
                LiveChartCard(
                    title: "Memória",
                    value: monitor.memory?.usedFraction.percent ?? "—",
                    detail: monitor.memory.map { "\($0.used.memoryBytes) de \($0.total.memoryBytes)" } ?? "",
                    history: monitor.memoryHistory,
                    maximum: 1
                )
                LiveChartCard(
                    title: "Download",
                    value: monitor.network?.download.rate ?? "—",
                    detail: "Upload \(monitor.network?.upload.rate ?? "—")",
                    history: monitor.downloadHistory,
                    maximum: nil
                )
            }
        }
    }
}
