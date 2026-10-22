import CleenKit
import SwiftUI

struct AppSummary: View {
    @Environment(AppsModel.self) private var model
    let app: InstalledApp

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            FileIcon(url: app.url, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(Theme.display(28))
                Text(facts)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                if app.isSystem {
                    Text("Faz parte do macOS e não pode ser removido.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.warning)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.removalSize.bytes)
                    .font(Theme.display(26))
                    .monospacedDigit()
                Text("com os dados")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var facts: String {
        var parts = [app.bundleID]
        if let version = app.version { parts.append("versão \(version)") }
        parts.append(app.isAppStore ? "App Store" : "Fora da App Store")
        if let lastUsed = app.lastUsed { parts.append("aberto \(lastUsed.relative)") }
        return parts.joined(separator: " · ")
    }
}
