import LustroKit
import SwiftUI

struct MonitorView: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Monitor", subtitle: "Ao vivo, atualizado a cada dois segundos.")
            VStack(alignment: .leading, spacing: 20) {
                LiveCharts()
                MemoryBreakdown()
                ProcessTable()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .task { await monitor.watchProcesses() }
    }
}
