import SwiftUI

/// One hover highlight for the whole bar, as in Screen Studio: a single rounded backdrop
/// behind the items that slides to whichever one the pointer is on. It moves only when
/// the pointer reaches another item and goes only when it leaves the bar, so the gaps
/// between items never make it flicker out and back.
struct ToolbarHoverContext {
    let hovered: Binding<String?>
}

extension EnvironmentValues {
    @Entry var toolbarHover: ToolbarHoverContext?
}

/// Each item's frame, by id, for the highlight to move to.
struct ToolbarItemFrames: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Joins the bar's shared hover highlight under `id`.
    func toolbarHoverItem(_ id: String) -> some View {
        modifier(ToolbarHoverItem(id: id))
    }

    /// Draws the shared highlight behind the items of this bar and owns its state.
    func toolbarHoverHighlight(_ hovered: Binding<String?>) -> some View {
        modifier(ToolbarHoverHighlight(hovered: hovered))
    }
}

/// Quick and settled, with no bounce: it follows the hand, it doesn't perform.
private let slide = Animation.spring(response: 0.28, dampingFraction: 0.9)

private struct ToolbarHoverItem: ViewModifier {
    let id: String
    @Environment(\.toolbarHover) private var hover

    func body(content: Content) -> some View {
        content
            .foregroundStyle(hover?.hovered.wrappedValue == id ? NotchStyle.primary : NotchStyle.secondary)
            .anchorPreference(key: ToolbarItemFrames.self, value: .bounds) { [id: $0] }
            .onHover { inside in
                // Only arriving counts: leaving an item for a gap keeps the highlight
                // where it is until the next item (or the bar is left).
                guard inside, let hover, hover.hovered.wrappedValue != id else { return }
                withAnimation(slide) { hover.hovered.wrappedValue = id }
            }
    }
}

private struct ToolbarHoverHighlight: ViewModifier {
    @Binding var hovered: String?

    func body(content: Content) -> some View {
        content
            .environment(\.toolbarHover, ToolbarHoverContext(hovered: $hovered))
            .backgroundPreferenceValue(ToolbarItemFrames.self) { frames in
                GeometryReader { proxy in
                    if let id = hovered, let anchor = frames[id] {
                        let rect = proxy[anchor]
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(NotchStyle.controlHover)
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                            .transition(.opacity)
                    }
                }
            }
            .onHover { inside in
                if !inside { withAnimation(.easeOut(duration: 0.18)) { hovered = nil } }
            }
    }
}
