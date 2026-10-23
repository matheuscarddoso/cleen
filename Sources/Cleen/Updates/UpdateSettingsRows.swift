import SwiftUI

/// Ajustes › Sobre: the version, whether there's a newer one, and the switch for
/// checking on its own.
struct UpdateSettingsRows: View {
    @Environment(UpdateModel.self) private var updates
    @AppStorage(UpdateModel.automaticKey) private var automatic = true

    var body: some View {
        SettingRow(title: String(localized: "Versão"), note: note) {
            HStack(spacing: 8) {
                Text(UpdateModel.currentVersion)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(NotchStyle.secondary)
                switch updates.phase {
                case .available(let feed):
                    Button(String(localized: "Atualizar para \(feed.version)")) { Task { await updates.install() } }
                        .buttonStyle(.notchPrimary)
                case .checking, .downloading, .installing:
                    ProgressView().controlSize(.small)
                default:
                    Button(String(localized: "Procurar agora")) { Task { await updates.check() } }
                        .buttonStyle(.notchSecondary)
                }
            }
        }
        SettingRow(title: String(localized: "Atualizar sozinho"), note: String(localized: "Procura uma versão nova a cada seis horas.")) {
            NotchSwitch(label: String(localized: "Atualizar sozinho"), isOn: $automatic)
        }
    }

    private var note: String? {
        switch updates.phase {
        case .upToDate: String(localized: "Esta é a versão mais nova.")
        case .available(let feed): feed.notes ?? String(localized: "Uma versão nova está pronta.")
        case .downloading: String(localized: "Baixando…")
        case .installing: String(localized: "Instalando, o Cleen abre de novo em seguida.")
        case .failed(let message): message
        default: nil
        }
    }
}
