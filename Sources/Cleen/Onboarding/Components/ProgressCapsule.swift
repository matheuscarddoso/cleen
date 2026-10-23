import SwiftUI

/// How far along the tour is: a short capsule that fills in Cleen's blue, the way the
/// icon is lit, with a soft leading edge.
struct ProgressCapsule: View {
    let progress: Double

    static let blue = Color(red: 0.10, green: 0.40, blue: 0.96)
    static let lightBlue = Color(red: 0.36, green: 0.67, blue: 1.0)

    var body: some View {
        Capsule()
            .fill(NotchStyle.track)
            .frame(width: 76, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Self.lightBlue, Self.blue, Self.blue.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, 76 * progress))
            }
            .accessibilityElement()
            .accessibilityLabel("Progresso")
            .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
