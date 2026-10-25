import CleenKit
import SwiftUI

/// Free space as the headline in a light, large figure, with the one action under it.
struct DiskSummary: View {
    let controller: NotchController
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Disco")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
            Text(monitor.disk?.available.bytes ?? "—")
                .font(.system(size: 34, weight: .light).monospacedDigit())
                .contentTransition(.numericText())
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.secondary)
            UsageBar(fraction: monitor.disk?.usedFraction ?? 0, height: 3.5)
                .padding(.vertical, 4)
            HStack(spacing: 8) {
                if app.isSmartScanning || app.isSmartCleaning {
                    ProgressView().controlSize(.small).tint(.white)
                    Text(app.isSmartScanning ? String(localized: "Analisando…") : String(localized: "Limpando…"))
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.secondary)
                } else if app.hasSmartResults, app.smartCleanSize > 0 {
                    ConfirmingButton(title: String(localized: "Limpar \(app.smartCleanSize.bytes)"), items: { app.junk.reviewItems + app.projects.reviewItems }, outcome: smartOutcome, action: clean)
                } else {
                    Button(app.hasSmartResults ? String(localized: "Analisar de novo") : String(localized: "Analisar o Mac"), action: scan)
                        .buttonStyle(.notchPrimary)
                }
            }
            if let report = app.smartReport {
                NotchReportLine(report: report)
            }
        }
        .animation(.smooth(duration: 0.25), value: app.isSmartScanning)
    }

    private var caption: String {
        guard let disk = monitor.disk else { return String(localized: "Lendo o disco…") }
        return String(localized: "livres de \(disk.total.bytes) · \(disk.usedFraction.percent) em uso")
    }

    private func scan() {
        Task { await app.smartScan() }
    }

    private func clean() {
        Task { await app.smartClean() }
    }

    /// Dependency folders are deleted outright, so with any of them it's at least mixed.
    private var smartOutcome: DeletionReview.Outcome {
        guard !app.projects.reviewItems.isEmpty else { return app.junk.reviewOutcome }
        if app.junk.reviewItems.isEmpty { return .delete }
        return app.junk.reviewOutcome == .delete ? .delete : .mixed
    }
}
