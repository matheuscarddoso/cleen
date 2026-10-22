import LustroKit
import SwiftUI

struct AppDetail: View {
    @Environment(AppsModel.self) private var model
    @State private var confirmingUninstall = false
    @State private var confirmingReset = false

    var body: some View {
        if let app = model.selectedApp {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        AppSummary(app: app)
                        if let report = model.report {
                            ReportBanner(report: report)
                        }
                        LeftoverList()
                    }
                    .padding(28)
                }
                if !app.isSystem {
                    CleanupBar(
                        selectedCount: model.leftoverSelection.count + 1,
                        selectedSize: model.removalSize,
                        actionTitle: "Desinstalar",
                        destination: "vão para o Lixo",
                        isWorking: model.isUninstalling,
                        action: confirmUninstall
                    )
                }
            }
            .confirmationDialog("Desinstalar \(app.name)?", isPresented: $confirmingUninstall) {
                Button("Desinstalar", role: .destructive, action: uninstall)
                if !model.leftoverSelection.isEmpty {
                    Button("Só apagar os dados (manter o app)", action: reset)
                }
            } message: {
                Text(uninstallMessage(app))
            }
        } else if model.report != nil {
            VStack(spacing: 18) {
                if let report = model.report {
                    ReportBanner(report: report)
                        .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView("Escolha um app", systemImage: "xmark.app", description: Text("Você vê o tamanho real dele, contando caches e dados, antes de remover."))
        }
    }

    private func uninstallMessage(_ app: InstalledApp) -> String {
        var text = "O app e \(model.leftoverSelection.count) itens relacionados vão para o Lixo."
        if model.isRunning(app) { text += " Ele será fechado antes." }
        if app.needsAdministrator { text += " O macOS vai pedir a senha de administrador." }
        return text
    }

    private func confirmUninstall() {
        confirmingUninstall = true
    }

    private func uninstall() {
        Task { await model.uninstall() }
    }

    private func reset() {
        Task { await model.reset() }
    }
}
