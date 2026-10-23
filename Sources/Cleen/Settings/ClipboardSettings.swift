import SwiftUI

struct ClipboardSettings: View {
    @Environment(ClipboardModel.self) private var clipboard
    @AppStorage(ClipboardModel.enabledKey) private var enabled = true

    var body: some View {
        NotchGroup {
            SettingRow(title: "Histórico da área de transferência", note: "Guarda as últimas 300 cópias neste Mac. Senhas de gerenciadores ficam de fora.") {
                NotchSwitch(label: "Histórico", isOn: $enabled)
            }
            SettingRow(title: "Apagar histórico", note: clipboard.log.entries.count.counted("item guardado", "itens guardados")) {
                ConfirmingButton(title: "Apagar", confirmTitle: "Confirmar", action: clipboard.clear)
                    .disabled(clipboard.log.entries.isEmpty)
            }
        }
    }
}
