import CleenKit
import SwiftUI

struct ProjectsView: View {
    @Environment(ProjectsModel.self) private var model
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Projetos de código", subtitle: subtitle) {
                ProjectRootsMenu()
                if model.phase == .ready {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.bordered)
                }
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: Route.projects.filledSymbol,
                    color: ToolPalette.color(for: .projects),
                    title: "Dependências de projetos parados",
                    message: promptMessage,
                    action: model.startScan
                )
            case .scanning:
                ScanningView(title: "Procurando projetos", detail: model.progress, cancel: model.cancel)
            case .ready where model.projects.isEmpty:
                AllClearView(title: "Nenhuma dependência instalada", message: "Não há node_modules, vendor nem builds nas pastas analisadas.", rescan: model.startScan)
            case .ready:
                ProjectsList()
                CleanupBar(
                    selectedCount: model.selectedCount,
                    selectedSize: model.selectedSize,
                    actionTitle: "Apagar",
                    destination: "apagados de vez, voltam com um install",
                    isWorking: model.isCleaning,
                    action: confirm
                )
            }
        }
        .confirmationDialog("Apagar \(model.selectedSize.bytes) de dependências e builds?", isPresented: $confirming) {
            Button("Apagar", role: .destructive, action: clean)
        } message: {
            Text("Seu código não é tocado. Cada pasta volta com o comando do projeto (npm install, composer install, swift build…).")
        }
    }

    private var subtitle: String {
        if model.phase == .ready, model.totalSize > 0 {
            return "\(model.totalSize.bytes) em \(model.projects.count) projetos · \(model.staleSize.bytes) em projetos parados"
        }
        return "node_modules, vendor, builds e caches que voltam com um comando."
    }

    private var promptMessage: String {
        let roots = model.roots.map { Paths.abbreviate($0) }
        guard !roots.isEmpty else {
            return "Escolha a pasta onde você guarda seus projetos em Pastas."
        }
        return "Vou procurar em \(roots.listed). Projetos sem mudança há mais de \(model.staleDays) dias já vêm marcados."
    }

    private func confirm() {
        confirming = true
    }

    private func clean() {
        Task { await model.clean() }
    }
}
