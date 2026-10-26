import SwiftUI

/// The closed notch while recording: a red dot on the left, the time on the right.
/// Clicking the notch opens Gravar with Stop.
struct RecordingWings: View {
    let since: Date
    let notchWidth: Double
    let inset: Double

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .phaseAnimator([1.0, 0.3]) { dot, opacity in dot.opacity(opacity) } animation: { _ in .easeInOut(duration: 0.8) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset + 4)
            Spacer(minLength: notchWidth)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(RecorderElapsed.text(from: since, to: context.date))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, inset + 2)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gravando")
    }
}
