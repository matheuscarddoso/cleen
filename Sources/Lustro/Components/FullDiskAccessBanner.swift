import LustroKit
import SwiftUI

/// Explains, once and plainly, why some places can't be read and how to fix it.
struct FullDiskAccessBanner: View {
    @Environment(\.openURL) private var openURL
    var message = "Sem Acesso Total ao Disco, o Lustro não enxerga a Lixeira, o Mail e o Safari."

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16))
                .foregroundStyle(Theme.warning)
                .accessibilityHidden(true)
            Text(message)
                .font(Theme.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Button("Abrir Ajustes", action: openSettings)
                .buttonStyle(.quiet)
        }
        .surface(radius: Theme.Radius.medium, padding: 12)
    }

    private func openSettings() {
        openURL(FullDiskAccess.settingsURL)
    }
}
