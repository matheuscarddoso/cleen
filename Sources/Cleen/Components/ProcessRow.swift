import AppKit
import CleenKit
import SwiftUI

/// A process with its icon, CPU and memory, and a quit button on hover.
struct ProcessRow: View {
    let process: ProcessUsage
    var compact = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let app = process.appURL {
                    FileIcon(url: app, size: compact ? 20 : 24)
                } else {
                    Image(systemName: "terminal")
                        .font(.system(size: compact ? 11 : 13))
                        .foregroundStyle(.secondary)
                        .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                }
            }
            Text(process.name)
                .font(compact ? Theme.caption : Theme.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if isHovered {
                Button("Encerrar", systemImage: "xmark.circle.fill", action: quit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Encerrar \(process.name)")
            }
            Text(process.cpu.cpuPercent)
                .frame(width: compact ? 42 : 56, alignment: .trailing)
            Text(process.memory.memoryBytes)
                .frame(width: compact ? 64 : 80, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .font(compact ? Theme.caption : Theme.body)
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 5 : 7)
        .background(isHovered ? Theme.surfaceHover : .clear, in: .rect(cornerRadius: Theme.Radius.small))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Encerrar", quit)
    }

    /// Apps get a normal quit (they can ask to save); plain processes get SIGTERM.
    private func quit() {
        if let app = NSRunningApplication(processIdentifier: process.pid) {
            app.terminate()
        } else {
            kill(process.pid, SIGTERM)
        }
    }
}
