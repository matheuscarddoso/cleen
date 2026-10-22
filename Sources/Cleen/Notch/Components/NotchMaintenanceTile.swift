import CleenKit
import SwiftUI

struct NotchMaintenanceTile: View {
    @Environment(MaintenanceModel.self) private var model
    let task: MaintenanceTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ToolIcon(symbol: task.symbol, color: ToolPalette.color(for: task), size: 24)
                Spacer()
                if task.needsAdministrator {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(NotchStyle.tertiary)
                        .help("Pede a senha de administrador")
                }
            }
            Text(task.title)
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(2, reservesSpace: true)
            status
                .frame(height: 24, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .notchCard(padding: 10)
        .help(task.summary)
    }

    @ViewBuilder
    private var status: some View {
        if model.running.contains(task) {
            ProgressView().controlSize(.mini).tint(.white)
        } else if let outcome = model.outcomes[task] {
            switch outcome {
            case .success(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.good)
                    .lineLimit(2)
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.warning)
                    .lineLimit(2)
            }
        } else {
            Button("Executar", action: run)
                .buttonStyle(.notchSecondary)
                .disabled(task == .thinSnapshots && model.snapshotCount == 0)
        }
    }

    private func run() {
        Task { await model.run(task) }
    }
}
