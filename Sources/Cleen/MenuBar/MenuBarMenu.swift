import SwiftUI

/// The menu bar item's menu: a way into the notch and the window, and out of the app.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Abrir o Cleen no notch", action: openNotch)
            .keyboardShortcut("c", modifiers: [.control, .option])
        Button("Abrir janela do Cleen", action: openMain)
        Divider()
        if let disk = monitor.disk {
            Text("\(disk.available.bytes) livres de \(disk.total.bytes)")
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

    private func openMain() {
        openWindow(id: MainWindow.id)
        NSApp.activate()
    }

    private func openSettings() {
        app.route = .settings
        openMain()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
