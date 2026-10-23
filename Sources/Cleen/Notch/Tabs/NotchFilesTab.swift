import AppKit
import CleenKit
import SwiftUI

struct NotchFilesTab: View {
    @Environment(LargeFilesModel.self) private var model

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "doc.fill",
                color: ToolPalette.orange,
                title: "O que mais ocupa a sua pasta",
                message: "Arquivos acima de \(model.minimumMB) MB com a data do último uso. Nada vem marcado: você escolhe.",
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: "Procurando arquivos grandes", detail: model.progress, cancel: model.cancel)
        case .ready where model.files.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: "Nenhum arquivo grande", message: "Nada acima de \(model.minimumMB) MB fora das pastas do sistema.", buttonTitle: "Analisar de novo", action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: "selecionados de \(model.totalSize.bytes) em \(model.files.count) arquivos · vão para o Lixo") {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: "Mover para o Lixo", confirmTitle: "Confirmar", isWorking: model.isCleaning, action: trash)
                        .disabled(model.selectedCount == 0)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                NotchScroll {
                    VStack(spacing: 0) {
                        ForEach(model.files.prefix(40)) { file in
                            NotchRow(title: file.name, subtitle: "\(Paths.abbreviate(file.url.deletingLastPathComponent())) · usado \(file.lastUsed.relative)", action: { model.toggle(file) }) {
                                NotchCheckbox(state: model.selection.contains(file.url) ? .on : .off, label: file.name) { model.toggle(file) }
                                FileIcon(url: file.url, size: 22)
                            } trailing: {
                                Text(file.size.bytes)
                                    .font(NotchStyle.bodyMedium.monospacedDigit())
                                    .foregroundStyle(NotchStyle.secondary)
                                NotchIconButton(symbol: "magnifyingglass", help: "Mostrar no Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                            }
                        }
                    }
                }
            }
            .animation(.smooth(duration: 0.25), value: model.report)
        }
    }

    private func trash() {
        Task { await model.moveToTrash() }
    }
}
