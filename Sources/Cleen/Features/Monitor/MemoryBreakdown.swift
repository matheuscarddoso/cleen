import CleenKit
import SwiftUI

/// Where the memory is going, in Activity Monitor's terms.
struct MemoryBreakdown: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let memory = monitor.memory {
            HStack(spacing: 20) {
                LegendItem(color: Theme.accent, title: "Apps", value: memory.app.memoryBytes)
                LegendItem(color: Theme.accent.opacity(0.6), title: "Fixa", value: memory.wired.memoryBytes)
                LegendItem(color: Theme.accent.opacity(0.35), title: "Comprimida", value: memory.compressed.memoryBytes)
                LegendItem(color: Theme.track, title: "Cache de arquivos", value: memory.cached.memoryBytes)
                Spacer()
                LegendItem(
                    color: memory.swapUsed > 1_000_000_000 ? Theme.warning : Theme.track,
                    title: "Swap",
                    value: memory.swapUsed.memoryBytes
                )
            }
            .font(Theme.caption)
        }
    }
}
