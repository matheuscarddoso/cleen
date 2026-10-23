import SwiftUI

struct ClipboardSettings: View {
    @Environment(ClipboardModel.self) private var clipboard
    @AppStorage(ClipboardModel.enabledKey) private var enabled = true
    @AppStorage(ScreenshotModel.opensNotchKey) private var screenshotOpens = true
    @AppStorage(ScreenshotModel.copiesOnCaptureKey) private var copiesOnCapture = false
    @Environment(ScreenshotModel.self) private var screenshots
    @State private var thumbnail = true

    var body: some View {
        group
            .onAppear {
                screenshots.refreshNativeThumbnail()
                thumbnail = screenshots.nativeThumbnailOn
            }
            .onChange(of: thumbnail) { _, on in
                guard on != screenshots.nativeThumbnailOn else { return }
                Task { await screenshots.setNativeThumbnail(on) }
            }
    }

    private var group: some View {
        NotchGroup {
            SettingRow(title: "Histórico da área de transferência", note: "Guarda as últimas 300 cópias neste Mac. Senhas de gerenciadores ficam de fora.") {
                NotchSwitch(label: "Histórico", isOn: $enabled)
            }
            SettingRow(title: "Abrir o notch ao tirar um screenshot", note: "Com opções para copiar, compartilhar, enviar por AirDrop ou excluir.") {
                NotchSwitch(label: "Screenshots", isOn: $screenshotOpens)
            }
            SettingRow(title: "Copiar o screenshot ao tirar", note: "Vai direto para a área de transferência, pronto para colar.") {
                NotchSwitch(label: "Copiar ao tirar", isOn: $copiesOnCapture)
            }
            SettingRow(title: "Miniatura do macOS", note: "Enquanto ela aparece, o arquivo não existe; desligada, o Cleen abre na hora.") {
                NotchSwitch(label: "Miniatura do macOS", isOn: $thumbnail)
            }
            SettingRow(title: "Apagar histórico", note: clipboard.log.entries.count.counted("item guardado", "itens guardados")) {
                ConfirmingButton(title: "Apagar", confirmTitle: "Confirmar", action: clipboard.clear)
                    .disabled(clipboard.log.entries.isEmpty)
            }
        }
    }
}
