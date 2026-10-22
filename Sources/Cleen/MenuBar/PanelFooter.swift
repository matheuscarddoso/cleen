import SwiftUI

struct PanelFooter: View {
    @Environment(AppModel.self) private var app
    @Environment(MaintenanceModel.self) private var maintenance
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 8) {
            Button("Abrir o Cleen", action: openMain)
                .buttonStyle(.quiet)
                .keyboardShortcut("o")
            Button(freeMemoryTitle, action: freeMemory)
                .buttonStyle(.quiet)
                .disabled(maintenance.running.contains(.freeMemory))
                .help("Esvazia o cache de arquivos da memória. Pede a senha de administrador.")
            Spacer()
            Menu {
                Button("Ajustes…", action: openSettings)
                Divider()
                Button("Sair do Cleen", action: quit)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Mais opções")
        }
    }

    private var freeMemoryTitle: String {
        if maintenance.running.contains(.freeMemory) { return "Liberando…" }
        if case .success(let message) = maintenance.outcomes[.freeMemory] { return message }
        return "Liberar memória"
    }

    private func openMain() {
        openWindow(id: MainWindow.id)
        NSApp.activate()
    }

    private func openSettings() {
        app.route = .settings
        openMain()
    }

    private func freeMemory() {
        Task { await maintenance.run(.freeMemory) }
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
