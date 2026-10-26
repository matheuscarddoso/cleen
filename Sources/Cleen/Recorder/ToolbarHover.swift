import SwiftUI

/// One hover highlight for the whole bar, as in Screen Studio: a single rounded backdrop
/// that slides from item to item under the pointer instead of each item lighting up on
/// its own.
struct ToolbarHoverContext {
    let namespace: Namespace.ID
    let hovered: Binding<String?>
}

extension EnvironmentValues {
    @Entry var toolbarHover: ToolbarHoverContext?
}

extension View {
    /// Joins the bar's shared hover highlight under `id`.
    func toolbarHoverItem(_ id: String) -> some View {
        modifier(ToolbarHoverItem(id: id))
    }
}

private struct ToolbarHoverItem: ViewModifier {
    let id: String
    @Environment(\.toolbarHover) private var hover

    /// Quick and settled, with no bounce: it follows the hand, it doesn't perform.
    static let slide = Animation.spring(response: 0.3, dampingFraction: 0.86)

    func body(content: Content) -> some View {
        content
            .foregroundStyle(hover?.hovered.wrappedValue == id ? NotchStyle.primary : NotchStyle.secondary)
            .background {
                if let hover, hover.hovered.wrappedValue == id {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(NotchStyle.controlHover)
                        .matchedGeometryEffect(id: "toolbar-hover", in: hover.namespace)
                }
            }
            .onHover { inside in
                guard let hover else { return }
                withAnimation(Self.slide) {
                    if inside {
                        hover.hovered.wrappedValue = id
                    } else if hover.hovered.wrappedValue == id {
                        hover.hovered.wrappedValue = nil
                    }
                }
            }
    }
}
