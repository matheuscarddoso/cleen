import CleenKit
import SwiftUI

/// What deleted apps left behind, one line per app.
struct NotchLeftoversTab: View {
    @Environment(OrphansModel.self) private var model
    @State private var expanded = Set<String>()

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "puzzlepiece.extension.fill",
                color: ToolPalette.yellow,
                title: String(localized: "O que ficou de apps apagados"),
                message: String(localized: "Arrastar um app para o Lixo deixa caches, preferências e dados para trás. O Cleen acha o que pertence a apps que não estão mais no Mac."),
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: String(localized: "Procurando restos"), detail: "")
        case .ready where model.groups.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: String(localized: "Nenhum resto"), message: String(localized: "Tudo em ~/Library pertence a apps instalados."), buttonTitle: String(localized: "Analisar de novo"), action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: caption) {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: String(localized: "Mover para o Lixo"), confirmTitle: String(localized: "Confirmar"), isWorking: model.isCleaning, action: trash)
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
                                subtitle: "\(group.bundleID) · \(group.items.map(\.place.title).uniqued().listed.localizedLowercase)",
                                verticalPadding: 4,
                                action: { model.toggle(group) }
                            ) {
                                NotchCheckbox(state: model.state(of: group), label: group.displayName) { model.toggle(group) }
                            } trailing: {
                                Text(group.totalSize.bytes)
                                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                                    .foregroundStyle(NotchStyle.secondary)
                                DisclosureChevron(isExpanded: expanded.contains(group.id)) {
                                    withAnimation(.smooth(duration: 0.2)) {
                                        if expanded.contains(group.id) { expanded.remove(group.id) } else { expanded.insert(group.id) }
                                    }
                                }
                            }
                            if expanded.contains(group.id) {
                                ForEach(group.items) { item in
                                    NotchChildRow(title: item.place.title, path: item.url, size: item.size, isOn: model.selection.contains(item.url)) {
                                        model.toggle(item)
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

    private var caption: String {
        let apps = model.groups.count
        let appsText = apps.counted(String(localized: "\(apps) app removido"), String(localized: "\(apps) apps removidos"))
        return String(localized: "de \(appsText) · vão para o Lixo")
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
