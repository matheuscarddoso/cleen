import CleenKit
import SwiftUI

/// One maintenance chore in a single line: icon, name, run.
struct NotchMaintenanceTile: View {
    @Environment(MaintenanceModel.self) private var model
    let task: MaintenanceTask

    var body: some View {
        HStack(spacing: 10) {
            ToolIcon(symbol: task.symbol, color: ToolPalette.color(for: task), size: 24)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if task.needsAdministrator {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(NotchStyle.tertiary)
                            .help("Pede a senha de administrador")
                    }
                }
                Text(statusText)
                    .font(NotchStyle.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.running.contains(task) {
                ProgressView().controlSize(.mini).tint(.white)
            } else {
                Button("Executar", action: run)
                    .buttonStyle(.notchSecondary)
                    .controlSize(.small)
                    .disabled(task == .thinSnapshots && model.snapshotCount == 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(NotchStyle.cardStroke)
        }
        .help(task.summary)
    }

    private var statusText: String {
        switch model.outcomes[task] {
        case .success(let message): message
        case .failure(let message): message
        case nil where task == .thinSnapshots && model.snapshotCount == 0: "Nenhum snapshot agora"
        case nil: task.needsAdministrator ? "Pede senha" : "Rápido e seguro"
        }
    }

    private var statusColor: Color {
        switch model.outcomes[task] {
        case .success: NotchStyle.good
        case .failure: NotchStyle.warning
        case nil: NotchStyle.tertiary
        }
    }

    private func run() {
        Task { await model.run(task) }
    }
}
