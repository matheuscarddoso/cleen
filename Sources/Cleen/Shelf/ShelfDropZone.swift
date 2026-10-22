import SwiftUI

/// Dashed drop area while empty; a row of draggable files once something is parked.
struct ShelfDropZone: View {
    @Environment(ShelfModel.self) private var shelf
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isTargeted ? NotchStyle.control : Color.white.opacity(0.03))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(isTargeted ? NotchStyle.primary.opacity(0.6) : NotchStyle.primary.opacity(0.22))
            if shelf.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .medium))
                    VStack(spacing: 2) {
                        Text("Solte arquivos aqui")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Ficam por um dia · segure ⌥ e clique para tirar")
                            .font(NotchStyle.caption)
                            .foregroundStyle(NotchStyle.secondary)
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(shelf.items) { item in
                            ShelfFileTile(item: item)
                        }
                    }
                    .padding(10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.smooth(duration: 0.15), value: isTargeted)
        .animation(.smooth(duration: 0.25), value: shelf.items)
    }
}
