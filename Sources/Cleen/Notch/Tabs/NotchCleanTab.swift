import CleenKit
import SwiftUI

/// System junk: every category with its size, pick and clean without leaving the notch.
struct NotchCleanTab: View {
    @Environment(JunkModel.self) private var model
    @State private var expanded = Set<String>()

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "trash.fill",
                color: ToolPalette.pink,
                title: String(localized: "Caches, logs e restos de desenvolvimento"),
                message: String(localized: "O que os apps recriam sozinhos e o que ficou para trás: DerivedData, npm, Composer, instaladores esquecidos."),
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: String(localized: "Procurando lixo"), detail: model.progress, cancel: model.cancel)
        case .ready where model.results.isEmpty && model.tools.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: String(localized: "Nada para limpar"), message: String(localized: "Não sobrou cache nem log que valha a pena remover."), buttonTitle: String(localized: "Analisar de novo"), action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: caption) {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: String(localized: "Limpar"), confirmTitle: String(localized: "Confirmar"), isWorking: model.isCleaning, action: clean)
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
                                let id = result.category.id
                                NotchRow(title: result.category.title, subtitle: subtitle(for: result), action: { model.toggle(result) }) {
                                    NotchCheckbox(state: model.state(of: result), label: result.category.title) { model.toggle(result) }
                                    ToolIcon(symbol: result.category.symbol, color: ToolPalette.color(for: result.category))
                                } trailing: {
                                    Text(result.totalSize.bytes)
                                        .font(NotchStyle.bodyMedium.monospacedDigit())
                                        .foregroundStyle(NotchStyle.secondary)
                                    DisclosureChevron(isExpanded: expanded.contains(id)) { toggleExpanded(id) }
                                }
                                if expanded.contains(id) {
                                    ForEach(result.items) { item in
                                        NotchChildRow(title: item.name, path: item.url, size: item.size, isOn: model.selection.contains(item.url), note: item.note) {
                                            model.toggle(item)
                                        }
                                    }
                                }
                            case .tool(let tool):
                                NotchRow(title: tool.title, subtitle: tool.detail, action: { model.toggle(tool) }) {
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
        let destination = model.selectionDeletes ? String(localized: "caches saem de vez, o resto vai para o Lixo") : String(localized: "vai para o Lixo")
        return String(localized: "selecionados de \(model.totalSize.bytes) · \(destination)")
    }

    private func subtitle(for result: JunkCategoryResult) -> String {
        let selected = result.items.count { model.selection.contains($0.url) }
        let running = result.items.contains { $0.note != nil }
        let total = result.items.count
        let items = total.counted(String(localized: "\(total) item"), String(localized: "\(total) itens"))
        var text = selected == total ? items : String(localized: "\(selected) de \(items)")
        if running { text += String(localized: " · apps abertos ficam de fora") }
        return text
    }

    private func toggleExpanded(_ id: String) {
        withAnimation(.smooth(duration: 0.2)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }

    private func clean() {
        Task { await model.clean() }
    }
}
