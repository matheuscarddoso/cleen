import SwiftUI

/// The menu bar item's menu: into the notch (a tab, the search, Ajustes), a glance at the
/// Mac, the update when there is one, and out of the app. Whatever it opens stays open:
/// the pointer is up here, not at the notch.
struct MenuBarMenu: View {
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor
    @Environment(TabPreferences.self) private var tabs
    @Environment(UpdateModel.self) private var updates

    var body: some View {
        Button("Abrir o Cleen", systemImage: "rectangle.topthird.inset.filled") { app.notch.openHeld() }
            .keyboardShortcut("c", modifiers: [.control, .option])
        Button("Buscar", systemImage: "magnifyingglass") { app.notch.openSearch() }
            .keyboardShortcut(app.notch.searchShortcutAvailable ? KeyboardShortcut(.space, modifiers: .option) : nil)
        Menu {
            ForEach(tabs.visible) { tab in
                Button(tab.title, systemImage: tab.symbol) { app.notch.openHeld(tab: tab) }
            }
        } label: {
            Label("Abrir na aba", systemImage: "square.grid.2x2")
        }

        Divider()

        Section("Este Mac") {
            if let disk = monitor.disk {
                Label("\(disk.available.bytes) livres de \(disk.total.bytes)", systemImage: "internaldrive")
            }
            if let memory = monitor.memory {
                Label("Memória: \(memory.usedFraction.percent) em uso", systemImage: "memorychip")
            }
            if let cpu = monitor.cpu {
                Label("CPU: \(cpu.total.percent)", systemImage: "cpu")
            }
        }

        Divider()

        if let feed = updates.available {
            Button(String(localized: "Atualizar para \(feed.version)"), systemImage: "arrow.down.circle") { Task { await updates.install() } }
        } else {
            Button("Procurar atualizações", systemImage: "arrow.clockwise") { Task { await updates.check() } }
                .disabled(updates.isBusy)
        }
        Button("Ajustes…", systemImage: "gearshape") { app.notch.openHeld(settings: .general) }
            .keyboardShortcut(",")
        Button("Sobre o Cleen", systemImage: "info.circle") { app.notch.openHeld(settings: .about) }

        Divider()

        Button("Sair do Cleen", systemImage: "power") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
