import CleenKit
import SwiftUI

/// Processor and memory right now, with the last two minutes of CPU behind them. A tap
/// opens Sistema.
struct SystemWidget: View {
    let size: HomeWidgetSize
    @Environment(SystemMonitor.self) private var monitor
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .system } label: {
            switch size {
            case .small:
                HomeRing(fraction: cpu, color: NotchStyle.level(cpu)) {
                    VStack(spacing: -1) {
                        Text(cpu.percent)
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("CPU")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                }
                .frame(width: 80, height: 80)
            case .medium, .large:
                VStack(alignment: .leading, spacing: 7) {
                    HomeWidgetLabel(title: String(localized: "Sistema"), symbol: "cpu")
                    meter("CPU", fraction: cpu)
                    meter(String(localized: "Memória"), fraction: memory)
                    Sparkline(values: monitor.cpuHistory, maximum: 1)
                        .frame(height: 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .help("Abrir Sistema")
    }

    private var cpu: Double { monitor.cpu?.total ?? 0 }
    private var memory: Double { monitor.memory?.usedFraction ?? 0 }

    private func meter(_ label: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.primary.opacity(0.85))
                Spacer()
                Text(fraction.percent)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            UsageBar(fraction: fraction)
        }
        .accessibilityElement(children: .combine)
    }
}
