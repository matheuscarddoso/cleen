import AppKit
import CleenKit
import SwiftUI

/// The processes doing the most right now, with quit on hover.
struct NotchProcessList: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Pesando agora")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("CPU")
                    .frame(width: 52, alignment: .trailing)
                Text("Memória")
                    .frame(width: 70, alignment: .trailing)
                Color.clear.frame(width: 26)
            }
            .font(NotchStyle.caption)
            .foregroundStyle(NotchStyle.tertiary)
            .padding(.horizontal, 8)
            ForEach(top) { process in
                NotchRow(title: process.name) {
                    if let app = process.appURL {
                        FileIcon(url: app, size: 18)
                    } else {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                            .foregroundStyle(NotchStyle.secondary)
                            .frame(width: 18, height: 18)
                    }
                } trailing: {
                    Text(process.cpu.cpuPercent)
                        .frame(width: 52, alignment: .trailing)
                    Text(process.memory.memoryBytes)
                        .foregroundStyle(NotchStyle.secondary)
                        .frame(width: 70, alignment: .trailing)
                    NotchIconButton(symbol: "xmark", help: "Encerrar \(process.name)") { quit(process) }
                }
                .font(NotchStyle.caption.monospacedDigit())
            }
        }
    }

    private var top: [ProcessUsage] {
        Array(monitor.processes.sorted { ($0.cpu, $0.memory) > ($1.cpu, $1.memory) }.prefix(4))
    }

    /// Apps get a normal quit (they can ask to save); plain processes get SIGTERM.
    private func quit(_ process: ProcessUsage) {
        if let app = NSRunningApplication(processIdentifier: process.pid) {
            app.terminate()
        } else {
            kill(process.pid, SIGTERM)
        }
    }
}
