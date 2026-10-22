import SwiftUI

/// A thin mark at `fraction` of the width: where usage would be at an even pace.
struct PaceTick: View {
    let fraction: Double

    var body: some View {
        PaceTickShape(fraction: fraction)
            .fill(NotchStyle.primary.opacity(0.85))
            .frame(height: 9)
            .accessibilityHidden(true)
    }
}
