import SwiftUI

/// How the panel's content appears and leaves: it fades, blurs and settles from (or
/// sinks back into) the notch, always inside the black shape that clips it.
struct NotchContentEffect: ViewModifier {
    /// 1 = fully shown, 0 = gone.
    let visibility: Double

    func body(content: Content) -> some View {
        content
            .opacity(visibility)
            .blur(radius: (1 - visibility) * 8)
            .scaleEffect(0.9 + 0.1 * visibility, anchor: .top)
    }
}

extension AnyTransition {
    /// Arrives a beat after the shape starts growing; leaves quickly, before the shape
    /// has shrunk past it, so nothing is ever seen hanging outside the tray.
    static var notchPanel: AnyTransition {
        let effect = AnyTransition.modifier(
            active: NotchContentEffect(visibility: 0),
            identity: NotchContentEffect(visibility: 1)
        )
        return .asymmetric(
            insertion: effect.animation(.smooth(duration: 0.34).delay(0.07)),
            removal: effect.animation(.easeIn(duration: 0.13))
        )
    }

    /// The live-activity wings come back once the panel has closed.
    static var notchWings: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.smooth(duration: 0.25).delay(0.18)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }
}
