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
                NotchMeterRow(symbol: "trash", label: "Lixo", value: value(app.junk.phase, app.junk.totalSize), labelWidth: nil, action: { controller.state.tab = .clean }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "chevron.left.forwardslash.chevron.right", label: "Projetos parados", value: value(app.projects.phase, app.projects.staleSize), labelWidth: nil, action: { controller.state.tab = .projects }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "puzzlepiece.extension", label: "Restos de apps", value: value(app.orphans.phase, app.orphans.totalSize), labelWidth: nil, action: { controller.state.tab = .leftovers }) {
                    Color.clear
                }
                NotchMeterRow(symbol: "doc", label: "Arquivos grandes", value: value(app.largeFiles.phase, app.largeFiles.totalSize), labelWidth: nil, action: { controller.state.tab = .files }) {
                    Color.clear
                }
            }
        }
        .padding(.top, 4)
    }

    private func value(_ phase: ScanPhase, _ size: Int64) -> String {
        switch phase {
        case .idle: "—"
        case .scanning: "…"
        case .ready: size.bytes
        }
    }
}
