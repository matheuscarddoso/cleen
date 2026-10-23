import CleenKit
import SwiftUI

/// One chore: glyph, name, state, and a small run button.
struct NotchMaintenanceRow: View {
    @Environment(MaintenanceModel.self) private var model
    let task: MaintenanceTask

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(statusText)
                    .font(.system(size: 9.5))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if model.running.contains(task) {
                ProgressView().controlSize(.mini).tint(.white)
            } else {
                Button("Executar", action: run)
                    .buttonStyle(.notchSecondary)
                    .controlSize(.mini)
                    .disabled(task == .thinSnapshots && model.snapshotCount == 0)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .help(task.summary)
    }

    private var statusText: String {
        switch model.outcomes[task] {
        case .success(let message): message
        case .failure(let message): message
        case nil where task == .thinSnapshots && model.snapshotCount == 0: String(localized: "Nenhum snapshot agora")
        case nil: task.needsAdministrator ? String(localized: "Pede senha") : String(localized: "Rápido e seguro")
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
