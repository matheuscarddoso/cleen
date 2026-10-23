import SwiftUI

/// The closed notch's "working" mark: an arc turning on the ring's track, the same size
/// as the artwork so it sits where the artwork would.
struct WingSpinner: View {
    let size: Double
    @State private var turning = false

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.track, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(NotchStyle.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(turning ? 360 : 0))
        }
        .padding(1.25)
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { turning = true }
        }
        .accessibilityLabel("Analisando")
    }
}
