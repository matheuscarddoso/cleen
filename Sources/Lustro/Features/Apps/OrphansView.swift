import LustroKit
import SwiftUI

struct OrphansView: View {
    @Environment(OrphansModel.self) private var model
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Restos de apps", subtitle: subtitle) {
                if model.phase == .ready {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.quiet)
                }
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: "puzzlepiece.extension",
                    title: "O que ficou de apps apagados",
                    message: "Arrastar um app para o Lixo deixa para trás caches, preferências e dados. O Lustro acha o que pertence a apps que não estão mais no Mac.",
                    action: model.startScan
                )
            case .scanning:
                ScanningView(title: "Procurando restos", detail: "")
            case .ready where model.groups.isEmpty:
                AllClearView(title: "Nenhum resto", message: "Tudo em ~/Library pertence a apps instalados.", rescan: model.startScan)
            case .ready:
                OrphansList()
                CleanupBar(
                    selectedCount: model.selectedCount,
                    selectedSize: model.selectedSize,
                    actionTitle: "Mover para o Lixo",
                    destination: "vão para o Lixo",
                    isWorking: model.isCleaning,
                    action: confirm
                )
            }
        }
        .confirmationDialog("Mover \(model.selectedSize.bytes) de restos para o Lixo?", isPresented: $confirming) {
            Button("Mover para o Lixo", action: trash)
        } message: {
            Text("Se você reinstalar algum desses apps, ele começa do zero.")
        }
    }

    private var subtitle: String {
        model.phase == .ready && !model.groups.isEmpty
            ? "\(model.groups.count) apps removidos deixaram \(model.totalSize.bytes)"
            : "Dados de apps que você já apagou."
    }

    private func confirm() {
        confirming = true
    }

    private func trash() {
        Task { await model.moveToTrash() }
    }
}
