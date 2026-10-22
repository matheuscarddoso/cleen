import CleenKit
import SwiftUI

/// What deleted apps left behind, one line per app.
struct NotchLeftoversTab: View {
    @Environment(OrphansModel.self) private var model

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "puzzlepiece.extension.fill",
                color: ToolPalette.yellow,
                title: "O que ficou de apps apagados",
                message: "Arrastar um app para o Lixo deixa caches, preferências e dados para trás. O Cleen acha o que pertence a apps que não estão mais no Mac.",
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: "Procurando restos", detail: "")
        case .ready where model.groups.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: "Nenhum resto", message: "Tudo em ~/Library pertence a apps instalados.", buttonTitle: "Analisar de novo", action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: "de \(model.groups.count.counted("app removido", "apps removidos")) · vão para o Lixo") {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: "Mover para o Lixo", confirmTitle: "Confirmar", isWorking: model.isCleaning, action: trash)
                        .disabled(model.selectedCount == 0)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                NotchScroll {
                    NotchGroup {
                        ForEach(model.groups) { group in
                            NotchRow(
                                title: group.displayName,
                                subtitle: "\(group.bundleID) · \(group.items.map(\.place.rawValue).uniqued().listed.lowercased())",
                                verticalPadding: 4
                            ) {
                                NotchCheckbox(state: model.state(of: group), label: group.displayName) { model.toggle(group) }
                            } trailing: {
                                Text(group.totalSize.bytes)
                                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                                    .foregroundStyle(NotchStyle.secondary)
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

extension Array where Element: Hashable {
    /// Order-preserving de-duplication.
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
