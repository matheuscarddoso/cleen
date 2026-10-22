import CleenKit
import SwiftUI

/// The right column of the home tab: plain sections, no cards, like a glance list.
struct NotchVitalsColumn: View {
    @Environment(NotchState.self) private var state
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                NotchSectionLink(symbol: "chart.bar.fill", title: "Sistema") { state.tab = .system }
                VitalLine(label: "CPU", value: monitor.cpu?.total.percent ?? "—", fraction: monitor.cpu?.total ?? 0)
                VitalLine(
                    label: "Memória",
                    value: monitor.memory?.used.memoryBytes ?? "—",
                    fraction: monitor.memory?.usedFraction ?? 0,
                    tint: memoryTint
                )
            }
            if let battery = monitor.battery {
                VStack(alignment: .leading, spacing: 6) {
                    NotchSectionLink(symbol: battery.isCharging ? "battery.100.bolt" : "battery.75", title: "Bateria") { state.tab = .system }
                    VitalLine(
                        label: battery.isCharging ? "Carregando" : (battery.isPluggedIn ? "Na tomada" : "Na bateria"),
                        value: battery.level.percent,
                        fraction: battery.level,
                        tint: battery.level < 0.2 ? NotchStyle.critical : NotchStyle.good
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryTint: Color? {
        switch monitor.memory?.pressure {
        case .critical: NotchStyle.critical
        case .warning: NotchStyle.warning
        default: nil
        }
    }
}
