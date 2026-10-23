import CleenKit
import SwiftUI

/// Free space on the startup disk. A tap opens Visão geral to do something about it.
struct DiskWidget: View {
    let size: HomeWidgetSize
    @Environment(SystemMonitor.self) private var monitor
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .overview } label: {
            switch size {
            case .small: ring.frame(width: 80, height: 80)
            case .medium, .large:
                HStack(spacing: 12) {
                    ring.frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        HomeWidgetLabel(title: "Disco", symbol: "internaldrive")
                        Text(monitor.disk.map { $0.available.bytes } ?? "—")
                            .font(.system(size: 17, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text(monitor.disk.map { "livres de \(Self.roundedSize($0.total))" } ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(NotchStyle.secondary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Abrir a Visão geral")
    }

    /// "245 GB", "1,5 TB": a disk's size the way it's sold, without the decimals.
    static func roundedSize(_ bytes: Int64) -> String {
        let gigabytes = Double(bytes) / 1_000_000_000
        if gigabytes >= 1000 {
            return (gigabytes / 1000).formatted(.number.precision(.fractionLength(0...1)).locale(.cleen)) + " TB"
        }
        return gigabytes.formatted(.number.precision(.fractionLength(0)).locale(.cleen)) + " GB"
    }

    private var fraction: Double { monitor.disk?.usedFraction ?? 0 }

    private var ring: some View {
        HomeRing(fraction: fraction, color: NotchStyle.level(fraction)) {
            VStack(spacing: -1) {
                Text(fraction.percent)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
                Text("usado")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disco")
        .accessibilityValue("\(fraction.percent) usado")
    }
}
