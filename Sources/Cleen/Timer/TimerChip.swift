import SwiftUI

/// A preset length as a pill: grey on hover, lifted when it's the length in use.
struct TimerChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(isSelected ? NotchStyle.primary : NotchStyle.secondary)
                .frame(minWidth: 18)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(background, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.15), value: isHovered)
        .animation(.smooth(duration: 0.18), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return NotchStyle.selection }
        return isHovered && isEnabled ? NotchStyle.control : .clear
    }
}

/// Pomodoro's rounds as short bars: done ones full, the current one filling.
struct TimerRounds: View {
    let rounds: Int
    let current: Int
    /// How far the current focus round is; breaks show it done.
    let progress: Double

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...max(1, rounds), id: \.self) { index in
                Capsule()
                    .fill(NotchStyle.track)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(NotchStyle.barFill)
                                .frame(width: proxy.size.width * fill(index))
                        }
                    }
                    .clipShape(.capsule)
                    .frame(width: 16, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rodada \(current) de \(rounds)")
    }

    private func fill(_ index: Int) -> Double {
        if index < current { return 1 }
        if index == current { return max(0, min(1, progress)) }
        return 0
    }
}
