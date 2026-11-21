import AVFoundation
import SwiftUI

/// Marks a screen recording among the stills: ▶ and, where there's room, its length.
struct RecordingBadge: View {
    let url: URL
    var showsDuration = true
    @State private var duration: Duration?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: showsDuration ? 8 : 7, weight: .bold))
            if showsDuration, let duration {
                Text(duration.formatted(.time(pattern: .minuteSecond)))
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, showsDuration ? 6 : 4)
        .padding(.vertical, showsDuration ? 3 : 2.5)
        .background(.black.opacity(0.62), in: .capsule)
        .padding(showsDuration ? 6 : 4)
        .accessibilityHidden(true)
        .task(id: url) {
            guard showsDuration else { return }
            let seconds = (try? await AVURLAsset(url: url).load(.duration)).map(CMTimeGetSeconds) ?? 0
            duration = seconds.isFinite && seconds > 0 ? .seconds(seconds.rounded()) : nil
        }
    }
}
