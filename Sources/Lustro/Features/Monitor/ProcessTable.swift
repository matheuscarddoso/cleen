import AppKit
import LustroKit
import SwiftUI

struct ProcessTable: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var sortOrder = [KeyPathComparator(\ProcessUsage.cpu, order: .reverse)]
    @State private var selection: ProcessUsage.ID?
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "\(monitor.processes.count) processos seus")
                Spacer()
                TextField("Filtrar", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button("Encerrar", action: quitSelected)
                    .buttonStyle(.quiet)
                    .disabled(selection == nil)
            }
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Nome", value: \.name) { process in
                    HStack(spacing: 8) {
                        if let app = process.appURL {
                            FileIcon(url: app, size: 16)
                        } else {
                            Image(systemName: "terminal")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 16, height: 16)
                        }
                        Text(process.name)
                    }
                }
                TableColumn("CPU", value: \.cpu) { process in
                    Text(process.cpu.cpuPercent)
                        .monospacedDigit()
                }
                .width(70)
                TableColumn("Memória", value: \.memory) { process in
                    Text(process.memory.memoryBytes)
                        .monospacedDigit()
                }
                .width(90)
                TableColumn("PID", value: \.pid) { process in
                    Text(String(process.pid))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(60)
            }
            .scrollContentBackground(.hidden)
            .alternatingRowBackgrounds(.disabled)
            .clipShape(.rect(cornerRadius: Theme.Radius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium).strokeBorder(Theme.hairline)
            }
        }
    }

    private var rows: [ProcessUsage] {
        let filtered = search.isEmpty ? monitor.processes : monitor.processes.filter { $0.name.localizedStandardContains(search) }
        return filtered.sorted(using: sortOrder)
    }

    private func quitSelected() {
        guard let pid = selection else { return }
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.terminate()
        } else {
            kill(pid, SIGTERM)
        }
        selection = nil
    }
}
