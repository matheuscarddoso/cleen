import CleenKit
import SwiftUI

struct NotchProjectsTab: View {
    @Environment(ProjectsModel.self) private var model
    @State private var expanded = Set<URL>()

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "chevron.left.forwardslash.chevron.right",
                color: ToolPalette.purple,
                title: "Dependências de projetos parados",
                message: "node_modules, vendor, .next, target e builds em \(model.roots.map { Paths.abbreviate($0) }.listed). Voltam com um install.",
                action: model.startScan
            )
        case .scanning:
            NotchScanning(title: "Procurando projetos", detail: model.progress, cancel: model.cancel)
        case .ready where model.projects.isEmpty:
            NotchPrompt(symbol: "checkmark", color: ToolPalette.green, title: "Nenhuma dependência instalada", message: "Nada de node_modules, vendor ou builds nas pastas analisadas.", buttonTitle: "Analisar de novo", action: model.startScan)
        case .ready:
            VStack(alignment: .leading, spacing: 8) {
                NotchSummaryBar(value: model.selectedSize.bytes, caption: "selecionados · \(model.staleSize.bytes) em projetos parados há \(model.staleDays)+ dias") {
                    Button("Marcar parados", action: model.selectStale)
                        .buttonStyle(.notchSecondary)
                    ConfirmingButton(title: "Apagar", confirmTitle: "Confirmar", isWorking: model.isCleaning, action: clean)
                        .disabled(model.selectedCount == 0)
                }
                if let report = model.report {
                    NotchReportLine(report: report)
                }
                NotchScroll {
                    VStack(spacing: 0) {
                        ForEach(model.projects) { project in
                            let stale = project.isStale(threshold: model.staleThreshold)
                            NotchRow(
                                title: project.name,
                                subtitle: "\(project.artifacts.map(\.kind.folderName).listed) · mexido \(project.lastActivity.relative)",
                                subtitleColor: stale ? NotchStyle.warning.opacity(0.85) : NotchStyle.tertiary,
                                action: { model.toggle(project) }
                            ) {
                                NotchCheckbox(state: model.state(of: project), label: project.name) { model.toggle(project) }
                                ToolIcon(symbol: "folder.fill", color: stale ? ToolPalette.purple : ToolPalette.graphite)
                            } trailing: {
                                Text(project.totalSize.bytes)
                                    .font(NotchStyle.bodyMedium.monospacedDigit())
                                    .foregroundStyle(NotchStyle.secondary)
                                DisclosureChevron(isExpanded: expanded.contains(project.id)) { toggleExpanded(project.id) }
                            }
                            if expanded.contains(project.id) {
                                ForEach(project.artifacts) { artifact in
                                    NotchChildRow(title: artifact.kind.title, path: artifact.url, size: artifact.size, isOn: model.selection.contains(artifact.url), note: artifact.kind.restoreHint) {
                                        model.toggle(artifact)
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

    private func toggleExpanded(_ id: URL) {
        withAnimation(.smooth(duration: 0.2)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }

    private func clean() {
        Task { await model.clean() }
    }
}
