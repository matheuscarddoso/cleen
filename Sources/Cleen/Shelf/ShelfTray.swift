import SwiftUI

/// The tray as in NotchNook: one dashed rounded area across the tab holding the files
/// in a row. Click to pick, ⌘/⇧ to pick more, sweep empty space for a rubber band,
/// drag the picked files out together; click empty space (or "+") to add from Finder.
struct ShelfTray: View {
    @Environment(ShelfModel.self) private var shelf
    @Environment(NotchState.self) private var notch
    @State private var frames: [URL: CGRect] = [:]
    @State private var addFrame: CGRect?
    @State private var band: CGRect?
    @State private var hovered: ShelfHoverTarget?
    @State private var viewport = 0.0
    @State private var isTargeted = false
    @State private var isPointerInside = false

    private nonisolated static let space = "shelfTray"
    private static let radius = 16.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .fill(isTargeted ? NotchStyle.card : (isEmptyHovered ? NotchStyle.card.opacity(0.6) : .clear))
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(NotchStyle.primary.opacity(isTargeted ? 0.5 : 0.18))
            row
            if shelf.items.isEmpty {
                empty
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .clipShape(.rect(cornerRadius: Self.radius, style: .continuous))
        .dropDestination(for: URL.self) { urls, _ in
            withAnimation(.smooth(duration: 0.25)) { shelf.add(urls) }
            notch.isDraggingFiles = false
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.smooth(duration: 0.15), value: isTargeted)
        .animation(.smooth(duration: 0.15), value: isEmptyHovered)
    }

    private var isEmptyHovered: Bool { shelf.items.isEmpty && hovered == nil && isPointerInside }

    private var row: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(shelf.items) { item in
                    ShelfFileTile(item: item, isSelected: shelf.selection.contains(item.url), isHovered: hovered == .file(item.url))
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[item.url] = $0 }
                        .transition(.scale(0.85).combined(with: .opacity))
                }
                if !shelf.items.isEmpty {
                    ShelfAddTile(isHovered: hovered == .add)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { addFrame = $0 }
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .frame(minWidth: viewport, maxHeight: .infinity, alignment: .leading)
            .coordinateSpace(.named(Self.space))
            .overlay {
                ShelfTrayInteraction(
                    shelf: shelf,
                    notch: notch,
                    frames: liveFrames,
                    addFrame: shelf.items.isEmpty ? nil : addFrame,
                    onBand: { band = $0 },
                    onHover: { hovered = $0 }
                )
                .onHover { isPointerInside = $0 }
            }
            .overlay(alignment: .topLeading) {
                if let band {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(NotchStyle.primary.opacity(0.07))
                        .strokeBorder(NotchStyle.primary.opacity(0.35), lineWidth: 1)
                        .frame(width: max(band.width, 1), height: max(band.height, 1))
                        .offset(x: band.minX, y: band.minY)
                        .allowsHitTesting(false)
                }
            }
            .animation(.smooth(duration: 0.25), value: shelf.items)
        }
        .scrollIndicators(.never)
        .scrollEdgeFade(.horizontal)
        .onGeometryChange(for: Double.self) { $0.size.width } action: { viewport = $0 }
    }

    /// Frames of the files still on the shelf: a removed tile's last frame lingers in
    /// the dictionary until its row is laid out again.
    private var liveFrames: [URL: CGRect] {
        let present = Set(shelf.urls)
        return frames.filter { present.contains($0.key) }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isEmptyHovered ? NotchStyle.primary : NotchStyle.secondary)
            Text("Arraste arquivos ou clique para escolher")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isEmptyHovered ? NotchStyle.primary : NotchStyle.primary.opacity(0.85))
        }
    }
}
