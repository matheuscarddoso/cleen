import AppKit
import CleenKit
import SwiftUI

/// The closed notch's download ring: blue, filling with the real progress around an
/// arrow; while the size isn't known yet, a short arc turns instead.
struct DownloadRing: View {
    let fraction: Double?
    let size: Double

    static let blue = Color(red: 0.2, green: 0.6, blue: 1)

    var body: some View {
        ZStack {
            Circle().stroke(Self.blue.opacity(0.22), lineWidth: 2.4)
            if let fraction {
                Circle()
                    .trim(from: 0, to: max(0.03, min(1, fraction)))
                    .stroke(Self.blue, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.5), value: fraction)
            } else {
                TimelineView(.animation) { context in
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(Self.blue, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360))
                }
            }
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Self.blue)
        }
        .frame(width: size - 2, height: size - 2)
        .frame(width: size, height: size)
        .accessibilityLabel("Download")
        .accessibilityValue(fraction.map(\.percent) ?? "")
    }
}

/// How a download reads beside the camera: the time left once it's measured, else how
/// far along it is, else how much has arrived.
enum DownloadText {
    static func remaining(_ estimate: DownloadEstimate) -> String {
        if let seconds = estimate.remaining {
            let short = DownloadEstimate.shortDuration(seconds)
            switch short.unit {
            case .seconds: return String(localized: "\(short.value) s")
            case .minutes: return String(localized: "\(short.value) min")
            case .hours: return short.minutes > 0 ? String(localized: "\(short.value) h \(short.minutes) min") : String(localized: "\(short.value) h")
            }
        }
        if let fraction = estimate.fraction { return fraction.percent }
        return estimate.completed.bytes
    }
}

/// A download that just finished, Droppy's way: the notch grows into an island with the
/// file's icon, its name, its size and folder, and a check.
struct DownloadIsland: View {
    let url: URL
    let size: Int64
    let notchHeight: Double
    @State private var checked = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(NotchStyle.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(verbatim: "\(size.bytes) · \(FileManager.default.displayName(atPath: url.deletingLastPathComponent().path(percentEncoded: false)))")
                        .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(NotchStyle.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(NotchStyle.primary)
                    .symbolEffect(.bounce, value: checked)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                checked = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
