import AppKit
import CleenKit
import SwiftUI

/// The disk map: breadcrumbs, a donut of the biggest items, and the folder's contents.
struct NotchSpaceTab: View {
    @Environment(SpaceLensModel.self) private var model

    var body: some View {
        switch model.phase {
        case .idle:
            NotchPrompt(
                symbol: "chart.pie.fill",
                color: ToolPalette.indigo,
                title: "Onde está o seu espaço",
                message: "Mede cada pasta para você descer até o que pesa.",
                buttonTitle: "Mapear minha pasta"
            ) { model.scan(.home) }
        case .scanning:
            NotchScanning(title: "Medindo \(model.target.title.lowercased())", detail: model.progress.map { "\($0.items.counted) itens · \($0.bytes.bytes)" } ?? "", cancel: model.cancel)
        case .ready:
            if let node = model.current {
                VStack(alignment: .leading, spacing: 8) {
                    SpaceBreadcrumbs()
                    HStack(alignment: .top, spacing: 16) {
                        SpaceMiniDonut(node: node)
                            .frame(width: 118, height: 118)
                        NotchScroll {
                            NotchGroup {
                                ForEach(node.children) { child in
                                    SpaceChildRow(node: child, parentSize: node.size)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
