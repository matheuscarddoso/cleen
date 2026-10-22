import CleenKit
import EventKit
import SwiftUI

struct PermissionSettings: View {
    @State private var fullDisk = FullDiskAccess.isGranted
    @Environment(\.openURL) private var openURL

    var body: some View {
        NotchGroup {
            permission("Acesso Total ao Disco", note: "Para ver Lixeira, Mail, Safari e containers de outros apps.", granted: fullDisk) {
                openURL(FullDiskAccess.settingsURL)
            }
            permission("Calendário", note: "Para os eventos no Início e no Calendário.", granted: EKEventStore.authorizationStatus(for: .event) == .fullAccess) {
                AgendaModel.openPrivacySettings()
            }
            permission("Lembretes", note: "Para os lembretes no Início.", granted: EKEventStore.authorizationStatus(for: .reminder) == .fullAccess) {
                AgendaModel.openPrivacySettings()
            }
        }
        .task { fullDisk = FullDiskAccess.isGranted }
    }

    private func permission(_ title: String, note: String, granted: Bool, open: @escaping () -> Void) -> some View {
        SettingRow(title: title, note: note) {
            if granted {
                Label("Concedido", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NotchStyle.good)
            } else {
                Button("Permitir", action: open)
                    .buttonStyle(.notchPrimary)
            }
        }
    }
}
