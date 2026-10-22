import CleenKit
import SwiftUI

struct MetricsGrid: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                MetricTile(
                    title: "CPU",
                    value: monitor.cpu?.total.percent ?? "—",
                    detail: cpuDetail,
                    history: monitor.cpuHistory,
                    maximum: 1
                )
                MetricTile(
                    title: "Memória",
                    value: monitor.memory.map { $0.used.memoryBytes } ?? "—",
                    detail: memoryDetail.text,
                    detailColor: memoryDetail.color,
                    history: monitor.memoryHistory,
                    maximum: 1,
                    tint: memoryDetail.color ?? Theme.accent
                )
            }
            GridRow {
                MetricTile(
                    title: "Rede",
                    value: "↓ " + (monitor.network?.download.rate ?? "—"),
                    detail: "↑ " + (monitor.network?.upload.rate ?? "—"),
                    history: monitor.downloadHistory
                )
                if let battery = monitor.battery {
                    BatteryTile(battery: battery)
                } else {
                    MetricTile(title: "Temperatura", value: thermal.text, detail: "Estado térmico", detailColor: thermal.color)
                }
            }
        }
    }

    private var cpuDetail: String {
        guard let cpu = monitor.cpu else { return "Medindo…" }
        return "\(cpu.user.percent) apps · \(cpu.system.percent) sistema"
    }

    private var memoryDetail: (text: String, color: Color?) {
        guard let memory = monitor.memory else { return ("Medindo…", nil) }
        return switch memory.pressure {
        case .normal: ("de \(memory.total.memoryBytes) · pressão normal", nil)
        case .warning: ("Pressão alta", Theme.warning)
        case .critical: ("Pressão crítica", Theme.critical)
        }
    }

    private var thermal: (text: String, color: Color?) {
        switch monitor.thermalState {
        case .nominal: ("Normal", nil)
        case .fair: ("Morno", nil)
        case .serious: ("Quente", Theme.warning)
        case .critical: ("Crítico", Theme.critical)
        @unknown default: ("—", nil)
        }
    }
}
