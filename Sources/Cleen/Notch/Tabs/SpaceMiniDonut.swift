import Charts
import CleenKit
import SwiftUI

/// Up to seven biggest children as grey sectors, the rest as one dim slice.
struct SpaceMiniDonut: View {
    let node: SpaceNode

    var body: some View {
        Chart(slices) { slice in
            SectorMark(angle: .value("Tamanho", slice.size), innerRadius: .ratio(0.66), angularInset: 1.2)
                .cornerRadius(2.5)
                .foregroundStyle(slice.color)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 1) {
                Text(node.size.bytes)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text(node.name)
                    .font(.system(size: 9.5))
                    .foregroundStyle(NotchStyle.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            }
        }
        .accessibilityLabel("Gráfico de \(node.name)")
    }

    private var slices: [SpaceSlice] {
        let top = node.children.filter { !$0.isAggregate && $0.size > 0 }.prefix(7)
        var slices = top.enumerated().map { index, child in
            SpaceSlice(id: child.id, name: child.name, size: child.size, color: .white.opacity(0.85 - Double(index) * 0.09))
        }
        let rest = node.size - top.reduce(0) { $0 + $1.size }
        if rest > 0 {
            slices.append(SpaceSlice(id: "rest", name: "Outros", size: rest, color: .white.opacity(0.12)))
        }
        return slices
    }
}
