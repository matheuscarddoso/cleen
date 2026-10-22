import SwiftUI

/// The window that drops from the menu bar: disk at a glance, one-click cleanup,
/// live vitals and what's weighing on the Mac right now.
struct MenuBarPanel: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            DiskHero()
            MetricsGrid()
            TopConsumers()
            PanelFooter()
        }
        .padding(16)
        .frame(width: 348)
        .task { await monitor.watchProcesses() }
    }
}
