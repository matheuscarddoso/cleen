import CleenKit
import SwiftUI

/// The current folder: a donut of its biggest children beside the full list.
struct SpaceExplorer: View {
    @Environment(SpaceLensModel.self) private var model
    let node: SpaceNode
    @State private var highlighted: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Breadcrumbs()
                .padding(.horizontal, 32)
            if let report = model.report {
                ReportBanner(report: report)
                    .padding(.horizontal, 32)
            }
            HStack(alignment: .top, spacing: 28) {
                SpaceDonut(node: node, highlighted: $highlighted)
                    .frame(width: 280, height: 280)
                    .padding(.top, 8)
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(node.children) { child in
                            SpaceRow(node: child, parentSize: node.size, isHighlighted: highlighted == child.id)
                                .onHover { hovering in highlighted = hovering ? child.id : nil }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 32)
        }
        .animation(Theme.standard, value: node.id)
    }
}
