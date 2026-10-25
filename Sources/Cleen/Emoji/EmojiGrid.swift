import CleenKit
import SwiftUI

/// Where the category buttons can scroll to.
enum EmojiJumpTarget: Hashable {
    case recents
    case category(EmojiCategory)

    var title: String {
        switch self {
        case .recents: String(localized: "Recentes")
        case .category(let category): category.title
        }
    }

    var symbol: String {
        switch self {
        case .recents: "clock"
        case .category(let category):
            switch category {
            case .people: "face.smiling"
            case .nature: "pawprint"
            case .food: "fork.knife"
            case .activity: "soccerball"
            case .travel: "car"
            case .objects: "lightbulb"
            case .symbols: "heart"
            case .flags: "flag"
            case .all: "square.grid.2x2"
            }
        }
    }
}

/// The emoji: recents, then every category in Apple's order; while searching, the
/// matches alone, best first. `selection` is a position in `EmojiGrid.order(of:)`, the
/// cell the arrow keys move and Return pastes.
struct EmojiGrid: View {
    let model: EmojiModel
    let selection: Int
    @Binding var columns: Int
    let select: (Int) -> Void
    let use: (EmojiItem) -> Void

    static let cellWidth = 36.0
    static let spacing = 2.0

    /// Every cell in reading order, the way the grid lays them out.
    static func order(of model: EmojiModel) -> [EmojiItem] {
        model.isSearching ? model.results : model.recents + model.sections.flatMap(\.items)
    }

    /// The grid as it's drawn: rows of positions in the reading order. Each section starts
    /// a row of its own, so moving up or down keeps the column across sections.
    static func rows(of model: EmojiModel, columns: Int) -> [[Int]] {
        let width = max(columns, 1)
        let groups = model.isSearching ? [model.results.count] : [model.recents.count] + model.sections.map(\.items.count)
        var rows: [[Int]] = []
        var start = 0
        for count in groups where count > 0 {
            for rowStart in stride(from: 0, to: count, by: width) {
                rows.append(Array((start + rowStart)..<(start + min(rowStart + width, count))))
            }
            start += count
        }
        return rows
    }

    var body: some View {
        if !model.isLoaded {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isSearching && model.results.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: "face.dashed")
                    .font(.system(size: 18))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Nenhum emoji encontrado")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NotchScroll {
                // A fixed column count (from the width), so ↑ and ↓ land on the cell
                // straight above and below.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: max(columns, 1)), alignment: .leading, spacing: Self.spacing) {
                    if model.isSearching {
                        cells(model.results, from: 0)
                    } else {
                        if !model.recents.isEmpty {
                            section(.recents, items: model.recents, from: 0)
                        }
                        let offsets = sectionOffsets
                        ForEach(Array(model.sections.enumerated()), id: \.element.id) { index, section in
                            self.section(.category(section.category), items: section.items, from: offsets[index])
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .onGeometryChange(for: Int.self) { proxy in
                max(1, Int((proxy.size.width + Self.spacing) / (Self.cellWidth + Self.spacing)))
            } action: { columns = $0 }
            // Searching jumps back to the top instead of keeping a scroll position from
            // the full grid.
            .id(model.isSearching)
        }
    }

    /// Where each category's cells start in the reading order.
    private var sectionOffsets: [Int] {
        var start = model.recents.count
        return model.sections.map { section in
            defer { start += section.items.count }
            return start
        }
    }

    private func section(_ target: EmojiJumpTarget, items: [EmojiItem], from start: Int) -> some View {
        Section {
            cells(items, from: start)
        } header: {
            Text(target.title)
                .font(NotchStyle.captionMedium)
                .foregroundStyle(NotchStyle.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .padding(.bottom, 2)
                .id(target)
        }
    }

    private func cells(_ items: [EmojiItem], from start: Int) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
            let position = start + offset
            EmojiCell(item: item, isSelected: position == selection, hover: { select(position) }) { use(item) }
                .id(EmojiCellID(position: position))
        }
    }
}

/// A cell's scroll anchor: its place in the reading order.
struct EmojiCellID: Hashable {
    let position: Int
}

/// One emoji: large, on a grey square when selected (by the arrows or the pointer), its
/// name as the tooltip.
struct EmojiCell: View {
    let item: EmojiItem
    let isSelected: Bool
    let hover: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(item.emoji)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? NotchStyle.selection : .clear, in: .rect(cornerRadius: 8, style: .continuous))
                .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(EmojiPressStyle())
        // The pointer and the arrows share one selection, like the launcher.
        .onHover { if $0 { hover() } }
        .help(item.name)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A quick press-in so a click reads as taken before the paste lands.
private struct EmojiPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The row of category glyphs that scroll the grid to each section.
struct EmojiCategoryJumps: View {
    let categories: [EmojiJumpTarget]
    let jump: (EmojiJumpTarget) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(categories, id: \.self) { target in
                NotchIconButton(symbol: target.symbol, help: target.title) { jump(target) }
            }
        }
    }
}
