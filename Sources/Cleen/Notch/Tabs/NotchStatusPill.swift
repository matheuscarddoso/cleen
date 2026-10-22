import SwiftUI

/// One phrase for the Mac's overall state, worst problem first.
struct NotchStatusPill: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let status = self.status
        HStack(spacing: 5) {
            Circle().fill(status.color).frame(width: 6, height: 6)
            Text(status.text)
                .font(NotchStyle.captionMedium)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(status.color.opacity(0.14), in: .capsule)
        .foregroundStyle(status.color)
    }

    private var status: (text: String, color: Color) {
        if let disk = monitor.disk, disk.usedFraction > 0.95 { return ("Disco quase cheio", NotchStyle.critical) }
        if monitor.memory?.pressure == .critical { return ("Memória no limite", NotchStyle.critical) }
        if monitor.thermalState == .serious || monitor.thermalState == .critical { return ("Mac muito quente", NotchStyle.warning) }
        if let disk = monitor.disk, disk.usedFraction > 0.9 { return ("Pouco espaço", NotchStyle.warning) }
        if monitor.memory?.pressure == .warning { return ("Memória sob pressão", NotchStyle.warning) }
        return ("Tudo em ordem", NotchStyle.good)
    }
}
