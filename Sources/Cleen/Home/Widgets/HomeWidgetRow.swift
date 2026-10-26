import SwiftUI

/// Início's widgets side by side with hairline dividers, as NotchNook lays them out.
/// Fixed widths first; flexible widgets split what's left. When the row is wider than
/// the panel it scrolls sideways instead of squeezing anything.
struct HomeWidgetRow: View {
    let items: [HomeWidgetItem]
    /// The room the row has, in points.
    let available: Double
    var isEditing = false

    static let spacing = 16.0
    static let dividerHeight = 88.0

    var body: some View {
        let widths = Self.widths(for: items, available: available)
        let row = HStack(alignment: .center, spacing: Self.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(NotchStyle.track)
                        .frame(width: 1, height: Self.dividerHeight)
                        .opacity(isEditing ? 0 : 1)
                }
                Group {
                    if isEditing {
                        HomeWidgetEditFrame(item: item) {
                            HomeWidgetView(item: item)
                        }
                    } else {
                        HomeWidgetView(item: item)
                    }
                }
                .frame(width: widths[index])
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }

        if Self.totalWidth(widths) > available + 0.5 {
            // A scroll view clips at its edges, and in edit mode the dashed frames and the
            // remove buttons reach past the widgets: give them room inside, take it back outside.
            let room = isEditing ? 14.0 : 0
            ScrollView(.horizontal) { row.padding(room) }
                .scrollIndicators(.never)
                .scrollEdgeFade(.horizontal)
                .padding(-room)
        } else {
            row.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    static func totalWidth(_ widths: [Double]) -> Double {
        widths.reduce(0, +) + Double(max(0, widths.count - 1)) * (spacing * 2 + 1)
    }

    /// Each widget's width: its size's, plus an even share of the leftover room for the
    /// flexible ones.
    static func widths(for items: [HomeWidgetItem], available: Double) -> [Double] {
        let base = items.map(\.size.width)
        let flexible = items.indices.filter { items[$0].kind.isFlexible(at: items[$0].size) }
        let leftover = available - totalWidth(base)
        guard leftover > 0, !flexible.isEmpty else { return base }
        let share = (leftover / Double(flexible.count)).rounded(.down)
        return base.indices.map { flexible.contains($0) ? base[$0] + share : base[$0] }
    }
}
