import SwiftUI

/// The menu bar item's menu: into the notch, into Ajustes, out of the app.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        Button("Abrir o Cleen", action: openNotch)
            .keyboardShortcut("c", modifiers: [.control, .option])
        if let disk = monitor.disk {
            Text("\(disk.available.bytes) livres de \(disk.total.bytes)")
        }
        if let feed = app.updates.available {
            Button(String(localized: "Atualizar para \(feed.version)")) { Task { await app.updates.install() } }
        }
        Divider()
        Button("Ajustes…", action: openSettings)
            .keyboardShortcut(",")
        Button("Sair do Cleen", action: quit)
            .keyboardShortcut("q")
    }

    private func openNotch() {
        app.notch.open()
    }

    private func openSettings() {
        app.notch.openSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
