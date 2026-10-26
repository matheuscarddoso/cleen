import ServiceManagement
import SwiftUI

struct GeneralSettings: View {
    @Environment(AppModel.self) private var app
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        NotchGroup {
            SettingRow(title: String(localized: "Abrir ao iniciar a sessão"), note: loginError) {
                NotchSwitch(label: String(localized: "Abrir ao iniciar a sessão"), isOn: $launchesAtLogin)
            }
            SettingRow(title: String(localized: "Abrir e fechar o notch"), note: String(localized: "Funciona em qualquer app.")) {
                Text("⌃ ⌥ C")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(NotchStyle.control, in: .rect(cornerRadius: 6))
            }
            SettingRow(
                title: String(localized: "Buscar"),
                note: app.notch.searchShortcutAvailable
                    ? String(localized: "Apps, arquivos, janelas, comandos, emoji e contas, de qualquer app. ⌘K mostra o que mais cada item faz.")
                    : String(localized: "Outro app já usa ⌥ Espaço (o Raycast?). Tire o atalho de lá e abra o Cleen de novo.")
            ) {
                Text("⌥ Espaço")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(app.notch.searchShortcutAvailable ? NotchStyle.primary : NotchStyle.warning)
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
            loginError = String(localized: "Não deu para mudar: \(error.localizedDescription)")
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
