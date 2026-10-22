import SwiftUI

/// A thin quota-style bar: white while there's room, orange then red as it fills.
struct UsageBar: View {
    /// 0...1
    let fraction: Double
    var height = 4.0
    var tint: Color?

    var body: some View {
        ZStack {
            Capsule().fill(NotchStyle.track)
            LeadingCapsule(fraction: fraction)
                .fill(tint ?? NotchStyle.level(fraction))
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.3), value: fraction)
        .accessibilityHidden(true)
    }
}
