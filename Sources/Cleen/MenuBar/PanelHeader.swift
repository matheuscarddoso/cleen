import SwiftUI

struct PanelHeader: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text("Cleen")
                    .font(Theme.display(17))
            }
            Spacer()
            Text(status.text)
                .font(Theme.caption)
                .foregroundStyle(status.color)
        }
    }

    /// One phrase for the Mac's overall state, worst problem first.
    private var status: (text: String, color: Color) {
        if let disk = monitor.disk, disk.usedFraction > 0.95 {
            return ("Disco quase cheio", Theme.critical)
        }
        if monitor.memory?.pressure == .critical {
            return ("Memória no limite", Theme.critical)
        }
        if monitor.thermalState == .serious || monitor.thermalState == .critical {
            return ("Mac muito quente", Theme.warning)
        }
        if let disk = monitor.disk, disk.usedFraction > 0.9 {
            return ("Pouco espaço", Theme.warning)
        }
        if monitor.memory?.pressure == .warning {
            return ("Memória sob pressão", Theme.warning)
        }
        return ("Tudo em ordem", Theme.good)
    }
}
