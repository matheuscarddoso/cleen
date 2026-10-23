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
/// matches alone, best first.
struct EmojiGrid: View {
    let model: EmojiModel
    let use: (EmojiItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 36, maximum: 44), spacing: 2)]

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
                LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
                    if model.isSearching {
                        cells(model.results)
                    } else {
                        if !model.recents.isEmpty {
                            section(.recents, items: model.recents)
                        }
                        ForEach(model.sections) { section in
                            self.section(.category(section.category), items: section.items)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            // Searching jumps back to the top instead of keeping a scroll position from
            // the full grid.
            .id(model.isSearching)
        }
    }

    private func section(_ target: EmojiJumpTarget, items: [EmojiItem]) -> some View {
        Section {
            cells(items)
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

    private func cells(_ items: [EmojiItem]) -> some View {
        ForEach(items) { item in
            EmojiCell(item: item) { use(item) }
        }
    }
}

/// One emoji: large, lifts a grey square on hover, its name as the tooltip.
struct EmojiCell: View {
    let item: EmojiItem
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(item.emoji)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isHovered ? NotchStyle.control : .clear, in: .rect(cornerRadius: 8, style: .continuous))
                .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(EmojiPressStyle())
        .onHover { isHovered = $0 }
        .help(item.name)
        .accessibilityLabel(item.name)
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
