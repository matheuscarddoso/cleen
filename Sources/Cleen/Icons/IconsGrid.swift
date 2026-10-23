import CleenKit
import SwiftUI

/// What a cell can copy.
enum LucideCopyKind {
    case svg, name, jsx, html

    /// The confirmation once it's on the clipboard.
    var done: String {
        switch self {
        case .svg: String(localized: "SVG copiado")
        case .name: String(localized: "Nome copiado")
        case .jsx: String(localized: "JSX copiado")
        case .html: String(localized: "HTML copiado")
        }
    }
}

/// The icons: the ones copied last, then all of them A to Z; while searching, the
/// matches alone, best first.
struct IconsGrid: View {
    let model: LucideModel
    let copy: (LucideIcon, LucideCopyKind) -> Void

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 82), spacing: 6)]

    var body: some View {
        if model.isSearching && model.results.isEmpty {
            VStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(NotchStyle.tertiary)
                Text("Nenhum ícone encontrado")
                    .font(.system(size: 11.5))
                    .foregroundStyle(NotchStyle.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            NotchScroll {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    if model.isSearching {
                        cells(model.results, suggested: model.results.first?.name)
                    } else {
                        if !model.recents.isEmpty {
                            section(String(localized: "Recentes"), icons: model.recents)
                        }
                        section(String(localized: "Todos"), icons: model.icons)
                    }
                }
                .padding(.bottom, 4)
            }
            // Searching jumps back to the top instead of keeping the full grid's scroll.
            .id(model.isSearching)
        }
    }

    private func section(_ title: String, icons: [LucideIcon]) -> some View {
        Section {
            cells(icons, suggested: nil)
        } header: {
            Text(title)
                .font(NotchStyle.captionMedium)
                .foregroundStyle(NotchStyle.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }

    private func cells(_ icons: [LucideIcon], suggested: String?) -> some View {
        ForEach(icons) { icon in
            IconCell(
                icon: icon,
                isSuggested: icon.name == suggested,
                isCopying: model.copying == icon.name,
                copy: { kind in copy(icon, kind) },
                openPage: { model.openPage(icon) }
            )
        }
    }
}

/// One icon: the glyph large, its name small under it. A click copies the SVG; the
/// context menu has the other ways to paste it.
struct IconCell: View {
    let icon: LucideIcon
    /// The cell Return would copy (the top search result).
    var isSuggested = false
    var isCopying = false
    let copy: (LucideCopyKind) -> Void
    let openPage: () -> Void
    @State private var isHovered = false

    private static let glyphSize = 32.0

    var body: some View {
        Button { copy(.svg) } label: {
            VStack(spacing: 5) {
                LucideGlyph(icon: icon, size: Self.glyphSize)
                    .foregroundStyle(NotchStyle.primary.opacity(isHovered ? 1 : 0.88))
                    .opacity(isCopying ? 0.25 : 1)
                    .overlay {
                        if isCopying {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.white)
                                .transition(.opacity)
                        }
                    }
                Text(verbatim: icon.name)
                    .font(.system(size: 9.5))
                    .foregroundStyle(isHovered ? NotchStyle.primary.opacity(0.85) : NotchStyle.secondary)
                    .lineLimit(1)
                    // Kebab names share their starts ("circle-…"); the end tells them apart.
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(isHovered ? NotchStyle.control : NotchStyle.card, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSuggested ? NotchStyle.primary.opacity(0.35) : NotchStyle.cardStroke)
            }
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(IconPressStyle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.12)) { isHovered = hovering }
        }
        .animation(.smooth(duration: 0.15), value: isCopying)
        .contextMenu {
            Button("Copiar SVG") { copy(.svg) }
            Button("Copiar nome") { copy(.name) }
            Button("Copiar JSX") { copy(.jsx) }
            Button("Copiar como Blade/HTML") { copy(.html) }
            Divider()
            Button("Abrir em lucide.dev", action: openPage)
        }
        .help(icon.name)
        .accessibilityLabel(Text(verbatim: icon.name))
        .accessibilityHint("Copia o SVG")
    }
}

/// A quick press-in so a click reads as taken before the copy lands.
private struct IconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
