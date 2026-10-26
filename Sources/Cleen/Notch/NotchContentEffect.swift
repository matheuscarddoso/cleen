import SwiftUI

/// How the panel's content appears and leaves: it fades, blurs and settles from (or
/// sinks back into) the notch, always inside the black shape that clips it.
struct NotchContentEffect: ViewModifier {
    /// 1 = fully shown, 0 = gone.
    let visibility: Double

    func body(content: Content) -> some View {
        content
            .opacity(visibility)
            .blur(radius: (1 - visibility) * 12)
            .scaleEffect(0.96 + 0.04 * visibility, anchor: .top)
    }
}

struct BlurEffect: ViewModifier {
    let radius: Double

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

struct TrackSwapEffect: ViewModifier {
    let visibility: Double

    func body(content: Content) -> some View {
        content
            .opacity(visibility)
            .blur(radius: (1 - visibility) * 5)
            .scaleEffect(0.92 + 0.08 * visibility)
    }
}

extension AnyTransition {
    /// Arrives with the shape, blurred, and sharpens as it grows (Droppy's open); leaves
    /// quickly, before the shape has shrunk past it, so nothing is ever seen hanging
    /// outside the tray.
    static var notchPanel: AnyTransition {
        let effect = AnyTransition.modifier(
            active: NotchContentEffect(visibility: 0),
            identity: NotchContentEffect(visibility: 1)
        )
        return .asymmetric(
            insertion: effect.animation(.smooth(duration: 0.3).delay(0.02)),
            removal: effect.animation(.easeIn(duration: 0.1))
        )
    }

    /// One tool handing over to the next: a quick blur crossfade instead of a cut.
    static var toolSwap: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: TrackSwapEffect(visibility: 0), identity: TrackSwapEffect(visibility: 1))
                .animation(.smooth(duration: 0.26).delay(0.04)),
            removal: .opacity.combined(with: .modifier(active: BlurEffect(radius: 6), identity: BlurEffect(radius: 0)))
                .animation(.easeIn(duration: 0.12))
        )
    }

    /// The live-activity wings come back once the panel has closed.
    /// A new track's artwork, title or banner: in from a slight blur and scale, out by
    /// fading, so one song hands over to the next instead of cutting.
    static var trackSwap: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: TrackSwapEffect(visibility: 0), identity: TrackSwapEffect(visibility: 1)),
            removal: .opacity.animation(NotchStyle.liveExit)
        )
    }

    static var notchWings: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.smooth(duration: 0.25).delay(0.18)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }
}
