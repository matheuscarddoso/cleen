import CleenKit
import SwiftUI

/// The overview's headline: how full the disk is and the one button that helps.
struct OverviewHero: View {
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor
    let confirmClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greeting)
                    .font(Theme.eyebrow)
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(headline)
                    .font(Theme.display(40))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                Text(detail)
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
            }
            if let disk = monitor.disk {
                DiskUsageBar(disk: disk, reclaimable: app.hasSmartResults ? app.smartCleanSize : 0)
            }
            HStack(spacing: 10) {
                if app.isSmartScanning {
                    ProgressView().controlSize(.small)
                    Text("Analisando o Mac…")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                } else if app.isSmartCleaning {
                    ProgressView().controlSize(.small)
                    Text("Limpando…")
                        .font(Theme.body)
                        .foregroundStyle(.secondary)
                } else if app.hasSmartResults, app.smartCleanSize > 0 {
                    Button("Limpar \(app.smartCleanSize.bytes)", action: confirmClean)
                        .buttonStyle(.primaryLarge)
                        .keyboardShortcut(.defaultAction)
                    Button("Analisar de novo", action: scan)
                        .buttonStyle(.quiet)
                } else {
                    Button(app.hasSmartResults ? "Analisar de novo" : "Analisar o Mac", action: scan)
                        .buttonStyle(.primaryLarge)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(minHeight: 40)
            if let report = app.smartReport {
                ReportBanner(report: report)
            }
        }
        .animation(Theme.standard, value: app.isSmartScanning)
        .animation(Theme.standard, value: app.smartReport)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }

    private var headline: String {
        if let report = app.smartReport, report.freed > 0 {
            return "\(report.freed.bytes) a mais de espaço."
        }
        if app.hasSmartResults, app.smartCleanSize > 0 {
            return "Dá para liberar \(app.smartCleanSize.bytes) sem perder nada."
        }
        guard let disk = monitor.disk else { return "Lendo o disco…" }
        return "\(disk.available.bytes) livres no disco."
    }

    private var detail: String {
        guard let disk = monitor.disk else { return "" }
        let used = "\(disk.used.bytes) de \(disk.total.bytes) em uso."
        if app.hasSmartResults {
            return used + " Revise cada área abaixo ou limpe o que é seguro de uma vez."
        }
        return used + " A análise leva poucos segundos e não remove nada."
    }

    private func scan() {
        Task { await app.smartScan() }
    }
}
