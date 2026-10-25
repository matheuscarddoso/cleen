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
            SettingRow(title: String(localized: "Histórico da área de transferência"), note: String(localized: "Guarda as últimas 300 cópias neste Mac. Senhas de gerenciadores ficam de fora.")) {
                NotchSwitch(label: String(localized: "Histórico"), isOn: $enabled)
            }
            SettingRow(title: String(localized: "Abrir o notch ao tirar um screenshot"), note: String(localized: "Com opções para copiar, compartilhar, enviar por AirDrop ou excluir.")) {
                NotchSwitch(label: String(localized: "Screenshots"), isOn: $screenshotOpens)
            }
            SettingRow(title: String(localized: "Copiar o screenshot ao tirar"), note: String(localized: "Vai direto para a área de transferência, pronto para colar.")) {
                NotchSwitch(label: String(localized: "Copiar ao tirar"), isOn: $copiesOnCapture)
            }
            SettingRow(title: String(localized: "Usar também a miniatura do macOS"), note: String(localized: "O Cleen a substitui. Ligada, o arquivo só é salvo quando ela some, e o Cleen abre com atraso.")) {
                NotchSwitch(label: String(localized: "Miniatura do macOS"), isOn: $thumbnail)
            }
            SettingRow(title: String(localized: "Apagar histórico"), note: savedCount) {
                ConfirmingButton(title: String(localized: "Apagar"), items: historyItems, outcome: .delete, action: clipboard.clear)
                    .disabled(clipboard.log.entries.isEmpty)
            }
        }
    }

    /// The history as one row: its entries aren't worth listing one by one.
    private func historyItems() -> [DeletionReview.Item] {
        let count = clipboard.log.entries.count
        guard count > 0 else { return [] }
        return [DeletionReview.Item(id: "clipboard", name: String(localized: "Histórico da área de transferência"), detail: savedCount, symbol: "doc.on.clipboard")]
    }

    private var savedCount: String {
        let count = clipboard.log.entries.count
        return count.counted(String(localized: "\(count) item guardado"), String(localized: "\(count) itens guardados"))
    }
}
