import AppKit
import SwiftUI

struct AboutSettings: View {
    @Environment(CleanupService.self) private var cleanup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NotchGroup {
                SettingRow(title: "Versão") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.secondary)
                }
                SettingRow(title: "Liberado pelo Cleen") {
                    Text(cleanup.lifetimeFreed.bytes)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                SettingRow(title: "Privacidade", note: "Nada sai do seu Mac. Seus arquivos sempre vão para o Lixo; só caches que se recriam são apagados de vez.") {
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
