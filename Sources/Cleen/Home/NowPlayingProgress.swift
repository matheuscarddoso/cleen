import SwiftUI

/// Playhead bar with elapsed and total time underneath.
struct NowPlayingProgress: View {
    let position: TimeInterval
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            UsageBar(fraction: duration > 0 ? position / duration : 0, height: 4, tint: .white)
            HStack {
                Text(Self.clock(position))
                Spacer()
                Text(Self.clock(duration))
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(NotchStyle.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progresso")
        .accessibilityValue("\(Self.clock(position)) de \(Self.clock(duration))")
    }

    /// `3:40`
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let rest = total % 60
        return "\(minutes):" + (rest < 10 ? "0\(rest)" : "\(rest)")
    }
}
