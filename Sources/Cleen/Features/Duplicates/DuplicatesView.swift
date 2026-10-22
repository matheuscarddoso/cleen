import CleenKit
import SwiftUI

struct DuplicatesView: View {
    @Environment(DuplicatesModel.self) private var model
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Duplicados", subtitle: subtitle) {
                if model.phase == .ready {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.bordered)
                }
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: Route.duplicates.filledSymbol,
                    color: ToolPalette.color(for: .duplicates),
                    title: "Cópias idênticas, byte a byte",
                    message: "Compara o conteúdo, não o nome, em \(model.roots.map(\.lastPathComponent).listed). Fica sempre uma cópia de cada.",
                    action: model.startScan
                )
            case .scanning:
                ScanningView(title: "Comparando arquivos", detail: model.progress, cancel: model.cancel)
            case .ready where model.groups.isEmpty:
                AllClearView(title: "Nenhum duplicado", message: "Não há arquivos repetidos acima de 1 MB nessas pastas.", rescan: model.startScan)
            case .ready:
                DuplicatesList()
                CleanupBar(
                    selectedCount: model.selectedCount,
                    selectedSize: model.selectedSize,
                    actionTitle: "Mover cópias para o Lixo",
                    destination: "vão para o Lixo",
                    isWorking: model.isCleaning,
                    action: confirm
                )
            }
        }
        .confirmationDialog(dialogTitle, isPresented: $confirming) {
            Button("Mover para o Lixo", role: model.removesSomeGroupEntirely ? .destructive : nil, action: trash)
        } message: {
            Text(model.removesSomeGroupEntirely
                 ? "Atenção: em pelo menos um grupo todas as cópias estão marcadas, então nenhuma vai sobrar fora do Lixo."
                 : "Uma cópia de cada arquivo fica onde está. As outras vão para o Lixo.")
        }
    }

    private var dialogTitle: String {
        "Mover \(model.selectedCount) cópias para o Lixo?"
    }

    private var subtitle: String {
        model.phase == .ready && !model.groups.isEmpty
            ? "\(model.groups.count) arquivos repetidos · \(model.wastedSize.bytes) em cópias"
            : "Arquivos repetidos em Documentos, Downloads, Mesa, Imagens, Filmes e Música."
    }

    private func confirm() {
        confirming = true
    }

    private func trash() {
        Task { await model.moveToTrash() }
    }
}
