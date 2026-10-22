import CleenKit
import SwiftUI

/// Live vitals as a row of cards, then the processes doing the most.
struct NotchSystemTab: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                NotchMetricCard(
                    symbol: "cpu",
                    title: "CPU",
                    value: monitor.cpu?.total.percent ?? "—",
                    detail: monitor.cpu.map { "\($0.user.percent) apps · \($0.system.percent) sistema" } ?? "",
                    fraction: monitor.cpu?.total,
                    history: monitor.cpuHistory,
                    maximum: 1
                )
                NotchMetricCard(
                    symbol: "memorychip",
                    title: "Memória",
                    value: monitor.memory?.used.memoryBytes ?? "—",
                    detail: memoryDetail,
                    detailColor: memoryColor,
                    fraction: monitor.memory?.usedFraction,
                    history: monitor.memoryHistory,
                    maximum: 1
                )
                NotchMetricCard(
                    symbol: "network",
                    title: "Rede",
                    value: "↓ \(monitor.network?.download.rate ?? "—")",
                    detail: "↑ \(monitor.network?.upload.rate ?? "—")",
                    history: monitor.downloadHistory
                )
                if let battery = monitor.battery {
                    NotchMetricCard(
                        symbol: battery.isCharging ? "battery.100.bolt" : "battery.75",
                        title: "Bateria",
                        value: battery.level.percent,
                        detail: [battery.health.map { "saúde \($0.percent)" }, battery.cycleCount.map { "\($0) ciclos" }].compactMap { $0 }.joined(separator: " · "),
                        fraction: battery.level,
                        fractionTint: battery.level < 0.2 ? NotchStyle.critical : NotchStyle.good
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            NotchProcessList()
        }
        .task { await monitor.watchProcesses() }
    }

    private var memoryDetail: String {
        guard let memory = monitor.memory else { return "" }
        return switch memory.pressure {
        case .normal: "de \(memory.total.memoryBytes) · pressão normal"
        case .warning: "pressão alta"
        case .critical: "pressão crítica"
        }
    }

    private var memoryColor: Color? {
        switch monitor.memory?.pressure {
        case .critical: NotchStyle.critical
        case .warning: NotchStyle.warning
        default: nil
        }
    }
}
