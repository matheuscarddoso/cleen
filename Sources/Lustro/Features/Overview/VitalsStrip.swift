import SwiftUI

/// Live vitals at the bottom of the overview, the same readings as the menu bar.
struct VitalsStrip: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Agora")
                Spacer()
                Button("Abrir Monitor", action: openMonitor)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                    .font(Theme.caption)
            }
            MetricsGrid()
        }
    }

    private func openMonitor() {
        app.route = .monitor
    }
}
