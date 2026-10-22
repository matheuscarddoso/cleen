import LustroKit
import SwiftUI

struct LargeFilesView: View {
    @Environment(LargeFilesModel.self) private var model
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Arquivos grandes", subtitle: subtitle) {
                if model.phase == .ready {
                    Button("Analisar de novo", action: model.startScan)
                        .buttonStyle(.quiet)
                }
            }
            switch model.phase {
            case .idle:
                ScanPrompt(
                    symbol: "doc.badge.arrow.up",
                    title: "O que mais ocupa a sua pasta",
                    message: "Vídeos, imagens de disco e arquivos compactados acima de \(model.minimumMB) MB, com a data do último uso. Nada vem marcado: você escolhe.",
                    action: model.startScan
                )
            case .scanning:
                ScanningView(title: "Procurando arquivos grandes", detail: model.progress, cancel: model.cancel)
            case .ready where model.files.isEmpty:
                AllClearView(title: "Nenhum arquivo grande", message: "Nada acima de \(model.minimumMB) MB fora das pastas do sistema.", rescan: model.startScan)
            case .ready:
                LargeFilesList()
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
        .confirmationDialog("Mover \(model.selectedCount) arquivos para o Lixo?", isPresented: $confirming) {
            Button("Mover para o Lixo", action: trash)
        } message: {
            Text("Eles continuam recuperáveis no Lixo até você esvaziá-lo. O espaço só volta depois disso.")
        }
    }

    private var subtitle: String {
        model.phase == .ready && !model.files.isEmpty
            ? "\(model.files.count) arquivos somam \(model.totalSize.bytes)"
            : "Seus arquivos acima de \(model.minimumMB) MB, do maior para o menor."
    }

    private func confirm() {
        confirming = true
    }

    private func trash() {
        Task { await model.moveToTrash() }
    }
}
