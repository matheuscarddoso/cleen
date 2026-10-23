import SwiftUI

/// One ring spreading out from the disk and fading, over and over.
struct RippleRing: View {
    let delay: Double
    let isDone: Bool
    @State private var spread = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .strokeBorder((isDone ? NotchStyle.good : Color(red: 0.55, green: 0.75, blue: 1)).opacity(0.5), lineWidth: 1)
            .frame(width: 120, height: 120)
            .scaleEffect(spread ? 2.25 : 1)
            .opacity(spread ? 0 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 3.3).delay(delay).repeatForever(autoreverses: false)) { spread = true }
            }
    }
}
