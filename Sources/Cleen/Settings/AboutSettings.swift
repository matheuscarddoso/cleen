import AppKit
import SwiftUI

struct AboutSettings: View {
    @Environment(CleanupService.self) private var cleanup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                SettingRow(title: String(localized: "Versão")) {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.secondary)
                }
                SettingRow(title: String(localized: "Liberado pelo Cleen")) {
                    Text(cleanup.lifetimeFreed.bytes)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                SettingRow(title: String(localized: "Privacidade"), note: String(localized: "Nada sai do seu Mac. Seus arquivos sempre vão para o Lixo; só caches que se recriam são apagados de vez.")) {
                    EmptyView()
                }
            }
            HStack {
                Spacer()
                Button("Sair do Cleen") { NSApp.terminate(nil) }
                    .buttonStyle(.notchSecondary)
            }
        }
    }
}
