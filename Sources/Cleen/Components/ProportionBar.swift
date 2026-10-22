import SwiftUI

/// A hairline bar showing one item's share of the largest in its list.
struct ProportionBar: View {
    /// 0...1
    let fraction: Double
    var tint = Theme.accent

    var body: some View {
        ZStack {
            Capsule().fill(Theme.track)
            LeadingCapsule(fraction: fraction).fill(tint.opacity(0.85))
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
