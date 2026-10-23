import SwiftUI

/// Control Center's brightness slider in the notch's colors: a pill that fills white
/// from the left, the sun inside it. Drag or click anywhere on it; arrow keys and
/// VoiceOver adjust it in steps.
struct BrightnessSlider: View {
    let value: Double
    var minimum = 0.0
    let onChange: (Double) -> Void

    static let height = 24.0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filled = Self.height + (width - Self.height) * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(NotchStyle.control)
                Capsule()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: filled)
                Image(systemName: fraction < 0.5 ? "sun.min.fill" : "sun.max.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(width: Self.height)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(.capsule)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let position = (drag.location.x - Self.height / 2) / max(1, width - Self.height)
                        onChange(minimum + (1 - minimum) * min(1, max(0, position)))
                    }
            )
        }
        .frame(height: Self.height)
        .animation(.smooth(duration: 0.12), value: value)
        .accessibilityElement()
        .accessibilityLabel("Brilho")
        .accessibilityValue(value.percent)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(1, value + 0.1))
            case .decrement: onChange(max(minimum, value - 0.1))
            @unknown default: break
            }
        }
    }

    /// How full the pill is, 0...1, from the slider's own floor.
    private var fraction: Double {
        guard minimum < 1 else { return 1 }
        return min(1, max(0, (value - minimum) / (1 - minimum)))
    }
}
