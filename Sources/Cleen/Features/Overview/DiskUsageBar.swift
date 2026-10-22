import CleenKit
import SwiftUI

/// The disk as one wide bar: used, the part a cleanup would give back, and free.
struct DiskUsageBar: View {
    let disk: DiskStats
    let reclaimable: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiskUsageShape(used: usedFraction, reclaimable: reclaimableFraction)
                .frame(height: 10)
                .animation(Theme.standard, value: reclaimableFraction)
            HStack(spacing: 18) {
                LegendItem(color: .white.opacity(0.75), title: "Em uso", value: (disk.used - reclaimable).bytes)
                if reclaimable > 0 {
                    LegendItem(color: Theme.accent, title: "Pode sair", value: reclaimable.bytes)
                }
                LegendItem(color: Theme.track, title: "Livre", value: disk.available.bytes)
            }
            .font(Theme.caption)
        }
        .accessibilityElement(children: .combine)
    }

    private var usedFraction: Double {
        disk.total > 0 ? Double(disk.used - reclaimable) / Double(disk.total) : 0
    }

    private var reclaimableFraction: Double {
        disk.total > 0 ? Double(reclaimable) / Double(disk.total) : 0
    }
}
