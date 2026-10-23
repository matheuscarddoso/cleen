import AppKit
import CoreText
import SwiftUI

/// A parked file as Finder's icon view draws it: the real preview on top, the name
/// under it on two lines, the middle of a long name giving way so the end and the
/// extension stay readable. Drawing only: clicks, drags and menus belong to the tray.
struct ShelfFileTile: View {
    let item: ShelfItem
    let isSelected: Bool
    let isHovered: Bool
    @State private var image: NSImage?
    @Environment(\.displayScale) private var scale

    enum Metrics {
        static let width = 84.0
        static let thumbnail = 48.0
        static let top = 8.0
        static let nameWidth = width - 10
        static let nameFont = NSFont.systemFont(ofSize: 10.5, weight: .medium)

        /// Where the preview sits inside a tile's frame, for the drag images.
        static func thumbnailFrame(in tile: CGRect) -> CGRect {
            CGRect(x: tile.midX - thumbnail / 2, y: tile.minY + top, width: thumbnail, height: thumbnail)
        }
    }

    init(item: ShelfItem, isSelected: Bool, isHovered: Bool) {
        self.item = item
        self.isSelected = isSelected
        self.isHovered = isHovered
        _image = State(initialValue: ShelfThumbnails.shared.cached(item.url))
    }

    var body: some View {
        VStack(spacing: 5) {
            thumbnail
                .frame(width: Metrics.thumbnail, height: Metrics.thumbnail)
            ShelfFileName(name: item.url.lastPathComponent)
                .foregroundStyle(isSelected ? NotchStyle.primary : NotchStyle.primary.opacity(0.88))
        }
        .padding(.top, Metrics.top)
        .padding(.bottom, 7)
        .frame(width: Metrics.width, alignment: .top)
        .background(highlight, in: .rect(cornerRadius: 11, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(NotchStyle.primary.opacity(0.08))
            }
        }
        .animation(.smooth(duration: 0.12), value: isHovered)
        .task(id: item.url) {
            guard image == nil else { return }
            let loaded = await ShelfThumbnails.shared.load(item.url, side: Metrics.thumbnail, scale: scale)
            withAnimation(.smooth(duration: 0.18)) { image = loaded }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.url.lastPathComponent)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var highlight: Color {
        if isSelected { return NotchStyle.selection }
        return isHovered ? NotchStyle.card : .clear
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .transition(.opacity)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NotchStyle.card)
                .padding(4)
        }
    }
}

/// The name on up to two lines: the first breaks where Finder would, the second keeps
/// its end and loses its middle.
struct ShelfFileName: View {
    let name: String

    var body: some View {
        let lines = ShelfFileName.lines(for: name)
        VStack(spacing: 0) {
            Text(verbatim: lines.first)
                .lineLimit(1)
            if let rest = lines.rest {
                Text(verbatim: rest)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .multilineTextAlignment(.center)
        .frame(width: ShelfFileTile.Metrics.nameWidth)
    }

    private static var cache: [String: (first: String, rest: String?)] = [:]

    /// Splits the name where the first line runs out of room, breaking between words
    /// when it can. Measured once per name.
    static func lines(for name: String) -> (first: String, rest: String?) {
        if let hit = cache[name] { return hit }
        let text = name as NSString
        let attributed = NSAttributedString(string: name, attributes: [.font: ShelfFileTile.Metrics.nameFont])
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        // A little short of the frame, so SwiftUI's own layout never clips line one.
        let fits = CTTypesetterSuggestLineBreak(typesetter, 0, ShelfFileTile.Metrics.nameWidth - 3)
        let result: (first: String, rest: String?)
        if fits <= 0 || fits >= text.length {
            result = (name, nil)
        } else {
            let first = text.substring(to: fits).trimmingCharacters(in: .whitespaces)
            result = (first, text.substring(from: fits))
        }
        if cache.count > 500 { cache.removeAll() }
        cache[name] = result
        return result
    }
}

/// The last tile: a quiet "+" that opens the file picker.
struct ShelfAddTile: View {
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.secondary)
                .frame(width: ShelfFileTile.Metrics.thumbnail, height: ShelfFileTile.Metrics.thumbnail)
                .background(isHovered ? NotchStyle.control : NotchStyle.card, in: .rect(cornerRadius: 12, style: .continuous))
            Text("Adicionar")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(isHovered ? NotchStyle.primary : NotchStyle.secondary)
                .lineLimit(1)
        }
        .padding(.top, ShelfFileTile.Metrics.top)
        .padding(.bottom, 7)
        .frame(width: ShelfFileTile.Metrics.width, alignment: .top)
        .animation(.smooth(duration: 0.12), value: isHovered)
        .accessibilityLabel("Adicionar arquivos")
    }
}
