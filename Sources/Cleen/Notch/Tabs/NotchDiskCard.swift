import CleenKit
import SwiftUI

/// The home card: how full the disk is, and the smart scan that frees it.
struct NotchDiskCard: View {
    let controller: NotchController
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                NotchRing(fraction: monitor.disk?.usedFraction ?? 0, symbol: "internaldrive")
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(monitor.disk?.available.bytes ?? "—")
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.secondary)
                    if app.hasSmartResults, app.smartCleanSize > 0 {
                        Text("\(app.smartCleanSize.bytes) podem sair sem perder nada")
                            .font(NotchStyle.captionMedium)
                            .foregroundStyle(NotchStyle.good)
                    }
                }
                .animation(.smooth, value: monitor.disk?.available)
            }
            HStack(spacing: 8) {
                actions
                Spacer(minLength: 0)
            }
            .frame(height: 26)
            if let report = app.smartReport {
                NotchReportLine(report: report)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .notchCard(padding: 12)
        .animation(.smooth(duration: 0.25), value: app.isSmartScanning)
        .animation(.smooth(duration: 0.25), value: app.smartReport)
    }

    @ViewBuilder
    private var actions: some View {
        if app.isSmartScanning {
            ProgressView().controlSize(.small).tint(.white)
            Text("Analisando o Mac…")
                .font(NotchStyle.body)
                .foregroundStyle(NotchStyle.secondary)
        } else if app.isSmartCleaning {
            ProgressView().controlSize(.small).tint(.white)
            Text("Limpando…")
                .font(NotchStyle.body)
                .foregroundStyle(NotchStyle.secondary)
        } else if app.hasSmartResults, app.smartCleanSize > 0 {
            ConfirmingButton(title: "Limpar \(app.smartCleanSize.bytes)", confirmTitle: "Confirmar limpeza", action: clean)
            Button("Revisar", action: review)
                .buttonStyle(.notchSecondary)
        } else {
            Button(app.hasSmartResults ? "Analisar de novo" : "Analisar o Mac", action: scan)
                .buttonStyle(.notchPrimary)
        }
    }

    private var caption: String {
        guard let disk = monitor.disk else { return "Lendo o disco…" }
        return "livres de \(disk.total.bytes) · \(disk.usedFraction.percent) em uso"
    }

    private func scan() {
        Task { await app.smartScan() }
    }

    private func clean() {
        Task { await app.smartClean() }
    }

    private func review() {
        controller.state.tab = .clean
    }
}
