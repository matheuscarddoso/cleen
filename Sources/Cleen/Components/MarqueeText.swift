import SwiftUI

/// One line of text that, when it doesn't fit, scrolls sideways in an endless loop instead
/// of ending in an ellipsis, like a marquee: it rests at the start for a moment so the
/// beginning can be read, travels at a steady reading speed, and runs into a second copy
/// so the loop never jumps back. Text that fits sits still, exactly like a plain `Text`.
///
/// The edges fade only while text is passing them: at rest the first letter is crisp.
/// With Reduce Motion on, it truncates with an ellipsis instead; VoiceOver reads the text
/// once, never the copy.
struct MarqueeText: View {
    let text: String
    /// Points per second: slow enough to read along.
    var speed = 30.0
    /// Between the end of the text and the start of its copy.
    var gap = 36.0
    /// How long it rests at the start of each pass.
    var pause = 2.2
    /// How far an edge fades while text passes it.
    var fade = 12.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth = 0.0
    @State private var boxWidth = 0.0

    private var overflows: Bool { textWidth > boxWidth + 0.5 && boxWidth > 0 }

    var body: some View {
        // The plain line sets the height and the width on offer, as a `Text` would.
        label
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(overflows && !reduceMotion ? 0 : 1)
            .onGeometryChange(for: Double.self, of: { $0.size.width }) { boxWidth = $0 }
            .background(alignment: .leading) {
                // The text's own width, unconstrained.
                label.fixedSize().hidden()
                    .onGeometryChange(for: Double.self, of: { $0.size.width }) { textWidth = $0 }
            }
            .overlay(alignment: .leading) {
                if overflows, !reduceMotion {
                    scrolling
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .help(overflows ? text : "")
    }

    private var label: some View {
        Text(text).lineLimit(1)
    }

    /// One pass: the text slides left by its own width plus the gap, which brings the copy
    /// exactly to where the text started, so the next pass picks up without a seam.
    private var scrolling: some View {
        let travel = textWidth + gap
        return KeyframeAnimator(initialValue: 0.0, repeating: true) { x in
            HStack(spacing: gap) {
                label.fixedSize()
                label.fixedSize()
            }
            .offset(x: x)
            .frame(width: boxWidth, alignment: .leading)
            .clipped()
            .mask { mask(at: x, travel: travel) }
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(0, duration: pause)
                LinearKeyframe(-travel, duration: travel / speed)
            }
        }
        // A new title starts its own loop from the beginning.
        .id(text)
    }

    /// The leading edge fades in as the text leaves it and out again as the copy settles
    /// at the start; the trailing edge fades while there's more text beyond it.
    private func mask(at x: Double, travel: Double) -> some View {
        let moved = -x
        let leading = min(fade, moved, travel - moved)
        return HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: max(0, leading))
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: fade)
        }
    }
}
