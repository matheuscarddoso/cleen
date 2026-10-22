import SwiftUI

/// The panel's one action: scan, then clean what's safe, without opening a window.
struct CleanupStrip: View {
    @Environment(JunkModel.self) private var junk
    let openJunk: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch junk.phase {
            case .idle:
                Text("Veja quanto dá para liberar.")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Analisar", action: junk.startScan)
                    .buttonStyle(.primary)
            case .scanning:
                ProgressView().controlSize(.small)
                Text(junk.progress.isEmpty ? "Analisando…" : junk.progress)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            case .ready:
                readyContent
            }
        }
        .frame(minHeight: 32)
        .animation(Theme.standard, value: junk.phase)
    }

    @ViewBuilder
    private var readyContent: some View {
        if junk.isCleaning {
            ProgressView().controlSize(.small)
            Text("Limpando…")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
            Spacer()
        } else if junk.selectedSize > 0 {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(junk.selectedSize.bytes) para limpar")
                    .font(Theme.bodyMedium)
                Button("Revisar itens", action: openJunk)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                    .font(Theme.caption)
            }
            Spacer()
            Button("Limpar", action: clean)
                .buttonStyle(.primary)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.good)
                .accessibilityHidden(true)
            Text(junk.report?.headline ?? "Nada para limpar agora")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Analisar", action: junk.startScan)
                .buttonStyle(.quiet)
        }
    }

    private func clean() {
        Task { await junk.clean() }
    }
}
