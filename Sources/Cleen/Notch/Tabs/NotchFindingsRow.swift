import CleenKit
import SwiftUI

/// What the smart scan found, one tile per area; each opens its tool.
struct NotchFindingsRow: View {
    let controller: NotchController
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 8) {
            NotchFindingTile(
                symbol: "sparkles",
                color: ToolPalette.pink,
                title: "Lixo",
                value: app.junk.phase == .ready ? app.junk.totalSize.bytes : nil,
                isScanning: app.junk.phase == .scanning
            ) { controller.state.tab = .clean }
            NotchFindingTile(
                symbol: "chevron.left.forwardslash.chevron.right",
                color: ToolPalette.purple,
                title: "Projetos parados",
                value: app.projects.phase == .ready ? app.projects.staleSize.bytes : nil,
                isScanning: app.projects.phase == .scanning
            ) { controller.state.tab = .projects }
            NotchFindingTile(
                symbol: "puzzlepiece.extension.fill",
                color: ToolPalette.yellow,
                title: "Restos de apps",
                value: app.orphans.phase == .ready ? app.orphans.totalSize.bytes : nil,
                isScanning: app.orphans.phase == .scanning
            ) { controller.openWindow(.leftovers) }
        }
    }
}
