import SwiftUI

/// Staggered entrance for a page's pieces: each one rises a few points out of a blur,
/// a beat after the one before, so a new page reads top to bottom.
struct OnboardingReveal: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .blur(radius: shown || reduceMotion ? 0 : 6)
            .onAppear {
                withAnimation(.smooth(duration: 0.65).delay(0.1 + Double(index) * 0.07)) { shown = true }
            }
    }
}

extension View {
    func onboardingReveal(_ index: Int) -> some View {
        modifier(OnboardingReveal(index: index))
    }
}
