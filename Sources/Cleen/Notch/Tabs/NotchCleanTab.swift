import CleenKit
import SwiftUI

/// System junk: every category with its size, pick and clean without leaving the notch.
struct NotchCleanTab: View {
    @Environment(JunkModel.self) private var model

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "trash.fill",
                color: ToolPalette.pink,
                title: "Caches, logs e restos de desenvolvimento",
                message: "O que os apps recriam sozinhos e o que ficou para trás: DerivedData, npm, Composer, instaladores esquecidos.",
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: "Procurando lixo", detail: model.progress, cancel: model.cancel)
        case .ready where model.results.isEmpty && model.tools.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: "Nada para limpar", message: "Não sobrou cache nem log que valha a pena remover.", buttonTitle: "Analisar de novo", action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: caption) {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: "Limpar", confirmTitle: "Confirmar", isWorking: model.isCleaning, action: clean)
                        .disabled(model.selectedCount == 0)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                NotchScroll {
                    VStack(spacing: 0) {
                        ForEach(model.rows) { row in
                            switch row {
                            case .category(let result):
                                NotchRow(title: result.category.title, subtitle: subtitle(for: result)) {
                                    NotchCheckbox(state: model.state(of: result), label: result.category.title) { model.toggle(result) }
                                    ToolIcon(symbol: result.category.symbol, color: ToolPalette.color(for: result.category))
                                } trailing: {
                                    Text(result.totalSize.bytes)
                                        .font(NotchStyle.bodyMedium.monospacedDigit())
                                        .foregroundStyle(NotchStyle.secondary)
                                }
                            case .tool(let tool):
                                NotchRow(title: tool.title, subtitle: tool.detail) {
                                    NotchCheckbox(state: model.selectedTools.contains(tool.kind) ? .on : .off, label: tool.title) { model.toggle(tool) }
                                    ToolIcon(symbol: tool.symbol, color: ToolPalette.blue)
                                } trailing: {
                                    Text(tool.reclaimable.bytes)
                                        .font(NotchStyle.bodyMedium.monospacedDigit())
                                        .foregroundStyle(NotchStyle.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .animation(.smooth(duration: 0.25), value: model.report)
        }
    }

    private var caption: String {
        let destination = model.selectionDeletes ? "caches saem de vez, o resto vai para o Lixo" : "vai para o Lixo"
        return "selecionados de \(model.totalSize.bytes) · \(destination)"
    }

    private func subtitle(for result: JunkCategoryResult) -> String {
        let selected = result.items.count { model.selection.contains($0.url) }
        let running = result.items.contains { $0.note != nil }
        var text = selected == result.items.count
            ? result.items.count.counted("item", "itens")
            : "\(selected) de \(result.items.count.counted("item", "itens"))"
        if running { text += " · apps abertos ficam de fora" }
        return text
    }

    private func clean() {
        Task { await model.clean() }
    }
}
