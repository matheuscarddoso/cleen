import AppKit
import SwiftUI

struct AboutSettings: View {
    @Environment(CleanupService.self) private var cleanup
    @AppStorage(Diagnostics.sendsKey) private var sendsReports = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                UpdateSettingsRows()
                SettingRow(title: String(localized: "Liberado pelo Cleen")) {
                    Text(cleanup.lifetimeFreed.bytes)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                SettingRow(title: String(localized: "Privacidade"), note: String(localized: "Seus arquivos e o que você faz no Mac não saem dele. Seus arquivos sempre vão para o Lixo; só caches que se recriam são apagados de vez.")) {
                    EmptyView()
                }
                SettingRow(title: String(localized: "Enviar relatórios de erro"), note: String(localized: "Se o Cleen fechar sozinho, travar ou algo falhar, o relatório técnico vai para o desenvolvedor, sem seus arquivos, seu nome ou o nome do Mac.")) {
                    NotchSwitch(label: String(localized: "Enviar relatórios de erro"), isOn: $sendsReports)
                }
            }
            .onChange(of: sendsReports) { _, on in Diagnostics.shared.sendingChanged(to: on) }
            HStack {
                Spacer()
                Button("Sair do Cleen") { NSApp.terminate(nil) }
                    .buttonStyle(.notchSecondary)
            }
        }
    }
}
