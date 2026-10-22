import AppKit
import SwiftUI

/// A parked file: drag it out to move it anywhere, double-click to open, ⌥-click to
/// take it off the shelf.
struct ShelfFileTile: View {
    @Environment(ShelfModel.self) private var shelf
    let item: ShelfItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 5) {
            FileIcon(url: item.url, size: 44)
            Text(item.url.lastPathComponent)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 76)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isHovered ? NotchStyle.control : .clear, in: .rect(cornerRadius: 10, style: .continuous))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .draggable(item.url)
        .onTapGesture(count: 2, perform: open)
        .onTapGesture(perform: tap)
        .help(item.url.path(percentEncoded: false))
        .transition(.scale(0.8).combined(with: .opacity))
    }

    private func tap() {
        if NSEvent.modifierFlags.contains(.option) {
            withAnimation { shelf.remove(item) }
        }
    }

    private func open() {
        NSWorkspace.shared.open(item.url)
    }
}
