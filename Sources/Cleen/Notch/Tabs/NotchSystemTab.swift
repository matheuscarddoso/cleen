import CleenKit
import SwiftUI

/// Live vitals as one grouped list: label, thin bar, value.
struct NotchSystemTab: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        NotchGroup {
            NotchMeterRow(symbol: "cpu", label: "CPU", value: monitor.cpu?.total.percent ?? "—") {
                UsageBar(fraction: monitor.cpu?.total ?? 0, height: 3.5)
            }
            NotchMeterRow(
                symbol: "memorychip",
                label: String(localized: "Memória"),
                value: monitor.memory?.used.memoryBytes ?? "—",
                valueColor: memoryColor ?? NotchStyle.primary
            ) {
                UsageBar(fraction: monitor.memory?.usedFraction ?? 0, height: 3.5, tint: memoryColor)
            }
            NotchMeterRow(
                symbol: "internaldrive",
                label: String(localized: "Disco"),
                value: String(localized: "\(monitor.disk?.available.bytes ?? "—") livres"),
                valueColor: NotchStyle.level(monitor.disk?.usedFraction ?? 0) == NotchStyle.barFill ? NotchStyle.primary : NotchStyle.level(monitor.disk?.usedFraction ?? 0)
            ) {
                UsageBar(fraction: monitor.disk?.usedFraction ?? 0, height: 3.5)
            }
            NotchMeterRow(symbol: "network", label: String(localized: "Rede"), value: "↑ \(monitor.network?.upload.rate ?? "—")") {
                HStack(spacing: 8) {
                    Text("↓")
                        .font(.system(size: 10.5))
                        .foregroundStyle(NotchStyle.tertiary)
                    Sparkline(values: monitor.downloadHistory, tint: NotchStyle.barFill)
                        .frame(height: 14)
                    Text(monitor.network?.download.rate ?? "—")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.primary.opacity(0.85))
                        .fixedSize()
                }
            }
            if let battery = monitor.battery {
                NotchMeterRow(
                    symbol: battery.isCharging ? "battery.100.bolt" : "battery.75",
                    label: String(localized: "Bateria"),
                    value: battery.level.percent,
                    detail: battery.health.map { String(localized: "saúde \($0.percent)") }
                ) {
                    UsageBar(fraction: battery.level, height: 3.5, tint: battery.level < 0.2 ? NotchStyle.critical : NotchStyle.barFill)
                }
            }
        }
        .padding(.top, 4)
    }

    private var memoryColor: Color? {
        switch monitor.memory?.pressure {
        case .critical: NotchStyle.critical
        case .warning: NotchStyle.warning
        default: nil
        }
    }
}
