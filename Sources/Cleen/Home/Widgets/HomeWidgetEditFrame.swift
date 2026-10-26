import SwiftUI
import UniformTypeIdentifiers

/// A widget while Início is being edited: dimmed and inert, outlined, with a button to
/// take it off, the sizes it comes in, and a drag to move it.
struct HomeWidgetEditFrame<Content: View>: View {
    let item: HomeWidgetItem
    @ViewBuilder let content: Content
    @Environment(HomeLayout.self) private var layout
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            widget
            if item.kind.sizes.count > 1 {
                sizePicker
            } else {
                Text(item.kind.sizes.first?.label ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NotchStyle.tertiary)
                    .frame(height: 22)
            }
        }
    }

    private var widget: some View {
        content
            .allowsHitTesting(false)
            .opacity(layout.dragging == item.kind ? 0.25 : 0.5)
            // One height for every outline, so the row reads as a row of slots.
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isTargeted ? NotchStyle.primary.opacity(0.6) : NotchStyle.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .padding(-6)
            }
            .contentShape(.rect)
            .onDrag {
                layout.dragging = item.kind
                return NSItemProvider(object: item.kind.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: HomeWidgetDropDelegate(target: item.kind, layout: layout, isTargeted: $isTargeted))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(item.kind.title)
            // Beside the drag, not inside it: a click on the button with the slightest
            // movement used to start dragging the widget instead.
            .overlay(alignment: .topTrailing) { removeButton.offset(x: 15, y: -15) }
    }

    private var removeButton: some View {
        Button {
            withAnimation(.smooth(duration: 0.3)) { layout.remove(item.kind) }
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Color.white, in: .circle)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                // A wider target than the dot itself.
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help("Tirar do Início")
        .accessibilityLabel("Tirar \(item.kind.title) do Início")
    }

    private var sizePicker: some View {
        HStack(spacing: 1) {
            ForEach(item.kind.sizes) { size in
                let isSelected = size == item.size
                Button {
                    withAnimation(.smooth(duration: 0.3)) { layout.setSize(size, for: item.kind) }
                } label: {
                    Text(size.shortLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .black : NotchStyle.primary.opacity(0.8))
                        .frame(width: 22, height: 18)
                        .background(isSelected ? Color.white : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .help(size.label)
                .accessibilityLabel(size.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(NotchStyle.control, in: .capsule)
    }
}

/// Moves the dragged widget into place as it passes over another one, so the row
/// reflows under the pointer rather than only on drop.
private struct HomeWidgetDropDelegate: DropDelegate {
    let target: HomeWidgetKind
    let layout: HomeLayout
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
        guard let dragging = layout.dragging, dragging != target else { return }
        withAnimation(.smooth(duration: 0.3)) { layout.move(dragging, to: target) }
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        layout.dragging = nil
        return true
    }
}
