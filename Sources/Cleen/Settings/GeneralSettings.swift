import ServiceManagement
import SwiftUI

struct GeneralSettings: View {
    @AppStorage(MenuBarDisplay.storageKey) private var menuBarDisplay = MenuBarDisplay.freeSpace
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        NotchGroup {
            SettingRow(title: "Abrir ao iniciar a sessão", note: loginError) {
                NotchSwitch(label: "Abrir ao iniciar a sessão", isOn: $launchesAtLogin)
            }
            SettingRow(title: "Na barra de menus") {
                NotchSegmented(options: MenuBarDisplay.allCases.map { ($0.shortTitle, $0) }, selection: $menuBarDisplay)
            }
            SettingRow(title: "Abrir e fechar o notch", note: "Funciona em qualquer app.") {
                Text("⌃ ⌥ C")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(NotchStyle.control, in: .rect(cornerRadius: 6))
            }
        }
        .onChange(of: launchesAtLogin) { _, enabled in update(enabled) }
    }

    private func update(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Não deu para mudar: \(error.localizedDescription)"
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
