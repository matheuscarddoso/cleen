import CleenKit
import SwiftUI

struct MaintenanceCard: View {
    @Environment(MaintenanceModel.self) private var model
    let task: MaintenanceTask

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ToolIcon(symbol: task.symbol, color: ToolPalette.color(for: task), size: 30)
                Spacer()
                if task.needsAdministrator {
                    Label("Pede senha", systemImage: "lock")
                        .font(Theme.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(Theme.bodyMedium)
                Text(task.summary)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if task == .thinSnapshots, let count = model.snapshotCount {
                    Text(count == 0 ? "Nenhum snapshot local agora." : count == 1 ? "1 snapshot local agora." : "\(count) snapshots locais agora.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if model.running.contains(task) {
                    ProgressView().controlSize(.small)
                    Text("Executando…")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Executar", action: run)
                        .buttonStyle(.bordered)
                        .disabled(task == .thinSnapshots && model.snapshotCount == 0)
                    if let outcome = model.outcomes[task] {
                        OutcomeLabel(outcome: outcome)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .surface()
    }

    private func run() {
        Task { await model.run(task) }
    }
}
