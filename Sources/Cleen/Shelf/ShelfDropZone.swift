import SwiftUI

/// While files are being dragged to the notch: two places to let go, side by side, as
/// in NotchNook. The shelf (dashed) keeps them for a day; AirDrop (blue) sends them.
struct ShelfDropZones: View {
    var body: some View {
        HStack(spacing: 10) {
            ShelfDropZone(kind: .shelf)
            ShelfDropZone(kind: .airDrop)
        }
    }
}

struct ShelfDropZone: View {
    enum Kind {
        case shelf
        case airDrop
    }

    let kind: Kind
    @Environment(ShelfModel.self) private var shelf
    @Environment(NotchState.self) private var notch
    @State private var isTargeted = false

    private static let radius = 16.0

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: kind == .shelf ? "tray.and.arrow.down" : AirDropStyle.symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(symbolColor)
                .symbolEffect(.bounce, value: isTargeted)
                .symbolEffect(.variableColor.iterative, isActive: kind == .airDrop && isTargeted)
            VStack(spacing: 2) {
                title
                    .font(.system(size: 12.5, weight: .medium))
                subtitle
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { background }
        .scaleEffect(isTargeted ? 1.015 : 1)
        .contentShape(.rect(cornerRadius: Self.radius))
        .dropDestination(for: URL.self) { urls, _ in
            notch.isDraggingFiles = false
            switch kind {
            case .shelf: withAnimation(.smooth(duration: 0.25)) { shelf.add(urls) }
            case .airDrop: shelf.airDrop(urls)
            }
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isTargeted)
        .accessibilityElement(children: .combine)
    }

    private var title: Text {
        kind == .shelf ? Text("Shelf") : Text("AirDrop")
    }

    private var subtitle: Text {
        kind == .shelf ? Text("Guarde por um dia") : Text("Envie para aparelhos por perto")
    }

    private var symbolColor: Color {
        switch kind {
        case .shelf: isTargeted ? NotchStyle.primary : NotchStyle.secondary
        case .airDrop: isTargeted ? NotchStyle.primary : AirDropStyle.accent
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        switch kind {
        case .shelf:
            shape
                .fill(isTargeted ? NotchStyle.card : .clear)
                .overlay {
                    shape
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(NotchStyle.primary.opacity(isTargeted ? 0.55 : 0.2))
                }
        case .airDrop:
            shape
                .fill(isTargeted ? AirDropStyle.hover : AirDropStyle.fill)
                .overlay {
                    shape.strokeBorder(AirDropStyle.accent.opacity(isTargeted ? 0.45 : 0.14))
                }
        }
    }
}
