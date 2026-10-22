import LustroKit
import SwiftUI

/// The few processes doing the most right now.
struct TopConsumers: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: "Pesando agora")
            VStack(spacing: 0) {
                if top.isEmpty {
                    Text("Medindo…")
                        .font(Theme.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ForEach(top) { process in
                        ProcessRow(process: process, compact: true)
                    }
                }
            }
            .surface(radius: Theme.Radius.medium, padding: 4)
        }
    }

    /// Ranked by CPU, with memory breaking ties so an idle Mac still shows the heavy apps.
    private var top: [ProcessUsage] {
        Array(monitor.processes.sorted {
            ($0.cpu, $0.memory) > ($1.cpu, $1.memory)
        }.prefix(4))
    }
}
