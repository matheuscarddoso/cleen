import CleenKit
import SwiftUI

/// The disk, Weather-widget style: one big light number on the left, a divider, and
/// what can be cleaned as a list on the right.
struct NotchOverviewTab: View {
    let controller: NotchController
    @Environment(AppModel.self) private var app
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            DiskSummary(controller: controller)
                .padding(.leading, 4)
                .frame(width: 240, alignment: .leading)
            Rectangle()
                .fill(NotchStyle.separator)
                .frame(width: 1)
            NotchGroup {
                NotchMeterRow(symbol: "trash", label: String(localized: "Lixo"), value: value(app.junk.phase, app.junk.totalSize, scanned: app.junk.lastScan), labelWidth: nil, action: { controller.state.tab = .clean }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "chevron.left.forwardslash.chevron.right", label: String(localized: "Projetos parados"), value: value(app.projects.phase, app.projects.staleSize, scanned: app.projects.lastScan), labelWidth: nil, action: { controller.state.tab = .projects }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "puzzlepiece.extension", label: String(localized: "Restos de apps"), value: value(app.orphans.phase, app.orphans.totalSize, scanned: app.orphans.lastScan), labelWidth: nil, action: { controller.state.tab = .leftovers }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "doc", label: String(localized: "Arquivos grandes"), value: value(app.largeFiles.phase, app.largeFiles.totalSize, scanned: app.largeFiles.lastScan), labelWidth: nil, action: { controller.state.tab = .files }) {
                    Color.clear
                }
            }
        }
        .padding(.top, 4)
        // The rows are the tools' last scans: whatever is missing or stale is taken
        // again each time the tab comes on screen.
        .onAppear { app.refreshOverview() }
    }

    /// A row being taken again keeps its last number until the new one lands.
    private func value(_ phase: ScanPhase, _ size: Int64, scanned lastScan: Date?) -> String {
        switch phase {
        case .ready: size.bytes
        case .scanning: lastScan == nil ? "…" : size.bytes
        case .idle: "—"
        }
    }
}
