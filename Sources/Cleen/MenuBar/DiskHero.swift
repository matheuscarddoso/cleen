import SwiftUI

/// Free space as the headline, with the cleanup that would change it right below.
struct DiskHero: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                RingGauge(value: monitor.disk?.usedFraction ?? 0, tint: tint, lineWidth: 5)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(monitor.disk?.available.bytes ?? "—")
                        .font(Theme.display(30))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                .animation(Theme.standard, value: monitor.disk?.available)
            }
            CleanupStrip(openJunk: openJunk)
        }
        .surface(padding: 14)
    }

    private var caption: String {
        guard let disk = monitor.disk else { return "Lendo o disco…" }
        var text = "livres de \(disk.total.bytes)"
        if disk.purgeable > 1_000_000_000 {
            text += " · \(disk.purgeable.bytes) liberáveis pelo macOS"
        }
        return text
    }

    private var tint: Color {
        switch monitor.disk?.usedFraction ?? 0 {
        case 0.92...: Theme.critical
        case 0.8...: Theme.warning
        default: Theme.accent
        }
    }

    private func openJunk() {
        app.route = .junk
        openWindow(id: MainWindow.id)
        NSApp.activate()
    }
}
