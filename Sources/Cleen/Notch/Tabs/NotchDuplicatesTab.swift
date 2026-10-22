import AppKit
import CleenKit
import SwiftUI

/// Identical files, a group per file; the copy that stays is marked "fica".
struct NotchDuplicatesTab: View {
    @Environment(DuplicatesModel.self) private var model

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "square.on.square",
                color: ToolPalette.teal,
                title: "Cópias idênticas, byte a byte",
                message: "Compara o conteúdo, não o nome, em \(model.roots.map(\.lastPathComponent).listed). Fica sempre uma cópia de cada.",
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: "Comparando arquivos", detail: model.progress, cancel: model.cancel)
        case .ready where model.groups.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: "Nenhum duplicado", message: "Não há arquivos repetidos acima de 1 MB nessas pastas.", buttonTitle: "Analisar de novo", action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: "em \(model.selectedCount.counted("cópia", "cópias")) · \(model.groups.count.counted("arquivo repetido", "arquivos repetidos")) · vão para o Lixo") {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: "Mover para o Lixo", confirmTitle: "Confirmar", isWorking: model.isCleaning, action: trash)
                        .disabled(model.selectedCount == 0)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                NotchScroll {
                    VStack(spacing: 8) {
                        ForEach(model.groups) { group in
                            NotchGroup {
                                ForEach(group.files) { file in
                                    let removing = model.selection.contains(file.url)
                                    NotchRow(
                                        title: file.name,
                                        subtitle: Paths.abbreviate(file.url.deletingLastPathComponent()),
                                        verticalPadding: 4
                                    ) {
                                        NotchCheckbox(state: removing ? .on : .off, label: file.name) { model.toggle(file) }
                                        FileIcon(url: file.url, size: 20)
                                    } trailing: {
                                        Text(removing ? group.fileSize.bytes : "fica")
                                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                                            .foregroundStyle(removing ? NotchStyle.secondary : NotchStyle.good)
                                        NotchIconButton(symbol: "magnifyingglass", help: "Mostrar no Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                        }
                                    }
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
