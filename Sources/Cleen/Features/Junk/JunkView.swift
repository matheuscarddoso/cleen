import CleenKit
import SwiftUI

struct JunkView: View {
    @Environment(JunkModel.self) private var model
    @State private var confirming = false
    @State private var hasFullDiskAccess = FullDiskAccess.isGranted

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Lixo do sistema", subtitle: subtitle) {
                if model.phase == .ready {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.bordered)
                }
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: Route.junk.filledSymbol,
                    color: ToolPalette.color(for: .junk),
                    title: "Caches, logs e restos de desenvolvimento",
                    message: "O Cleen procura o que os apps recriam sozinhos e o que ficou para trás: caches, logs, DerivedData, pacotes de npm e Composer, instaladores esquecidos.",
                    action: model.startScan
                )
            case .scanning:
                ScanningView(title: "Procurando lixo", detail: model.progress, cancel: model.cancel)
            case .ready where model.results.isEmpty && model.tools.isEmpty:
                AllClearView(title: "Nada para limpar", message: "Não sobrou cache nem log que valha a pena remover.", rescan: model.startScan)
            case .ready:
                JunkResultsList(hasFullDiskAccess: hasFullDiskAccess)
                CleanupBar(
                    selectedCount: model.selectedCount,
                    selectedSize: model.selectedSize,
                    actionTitle: "Limpar",
                    destination: model.selectionDeletes ? "caches são apagados de vez" : "vão para o Lixo",
                    isWorking: model.isCleaning,
                    action: confirm
                )
            }
        }
        .confirmationDialog("Limpar \(model.selectedSize.bytes)?", isPresented: $confirming) {
            Button("Limpar", action: clean)
        } message: {
            Text("Caches, logs e dados de desenvolvimento são apagados de vez; os apps recriam o que precisarem. Instaladores e backups vão para o Lixo.")
        }
        .task { hasFullDiskAccess = FullDiskAccess.isGranted }
    }

    private var subtitle: String {
        switch model.phase {
        case .ready where model.totalSize > 0:
            "\(model.totalSize.bytes) encontrados · \(model.lastScan?.relative ?? "agora")"
        default:
            "O que pode sair sem que você perca nada."
        }
    }

    private func confirm() {
        confirming = true
    }

    private func clean() {
        Task { await model.clean() }
    }
}
