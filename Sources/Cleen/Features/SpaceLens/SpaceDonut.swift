import Charts
import CleenKit
import SwiftUI

/// Up to eight biggest children as sectors, everything else as one muted slice.
struct SpaceDonut: View {
    @Environment(SpaceLensModel.self) private var model
    let node: SpaceNode
    @Binding var highlighted: String?
    @State private var angle: Int64?

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Tamanho", slice.size),
                innerRadius: .ratio(0.64),
                angularInset: 1.2
            )
            .cornerRadius(3)
            .foregroundStyle(slice.color)
            .opacity(highlighted == nil || highlighted == slice.id ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $angle)
        .onChange(of: angle) { _, newValue in
            highlighted = newValue.flatMap(slice(at:))?.id
        }
        .chartBackground { _ in
            VStack(spacing: 4) {
                Text(centerTitle)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Text(centerSize.bytes)
                    .font(Theme.display(26))
                    .monospacedDigit()
            }
        }
        .onTapGesture(perform: openHighlighted)
        .animation(Theme.standard, value: highlighted)
        .accessibilityLabel("Gráfico de \(node.name)")
    }

    private var slices: [SpaceSlice] {
        let ranked = node.children.filter { !$0.isAggregate && $0.size > 0 }
        let top = ranked.prefix(8)
        var slices = top.enumerated().map { index, child in
            SpaceSlice(id: child.id, name: child.name, size: child.size, color: Theme.accent.opacity(1 - Double(index) * 0.1))
        }
        let rest = node.size - top.reduce(0) { $0 + $1.size }
        if rest > 0 {
            slices.append(SpaceSlice(id: "rest", name: "Outros", size: rest, color: Color.white.opacity(0.12)))
        }
        return slices
    }

    private func slice(at value: Int64) -> SpaceSlice? {
        var running: Int64 = 0
        for slice in slices {
            running += slice.size
            if value <= running { return slice }
        }
        return nil
    }

    private var highlightedNode: SpaceNode? {
        node.children.first { $0.id == highlighted }
    }

    private var centerTitle: String { highlightedNode?.name ?? node.name }
    private var centerSize: Int64 { highlightedNode?.size ?? node.size }

    private func openHighlighted() {
        if let highlightedNode { model.open(highlightedNode) }
    }
}
