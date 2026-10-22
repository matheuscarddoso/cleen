import CleenKit
import SwiftUI

struct AppListRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            FileIcon(url: app.url, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(Theme.body)
                    .lineLimit(1)
                Text(usage)
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(app.size.bytes)
                .font(Theme.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .opacity(app.isSystem ? 0.55 : 1)
    }

    private var usage: String {
        if app.isSystem { return "Faz parte do macOS" }
        guard let lastUsed = app.lastUsed else { return "Sem registro de uso" }
        return "Aberto \(lastUsed.relative)"
    }
}
