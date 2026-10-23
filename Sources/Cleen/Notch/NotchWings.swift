import CleenKit
import SwiftUI

/// Live activity beside the closed notch. While something plays: its artwork on the
/// left of the camera, moving sound bars on the right (as NotchNook does). Otherwise:
/// disk fullness and free space. During a scan or cleanup: progress.
struct NotchWings: View {
    let notchWidth: Double
    let notchHeight: Double
    @Environment(SystemMonitor.self) private var monitor
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app
    @Environment(NowPlayingModel.self) private var nowPlaying

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset)
            Spacer(minLength: notchWidth)
            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, inset)
        }
        .frame(maxHeight: .infinity)
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cleen")
    }

    /// Artwork as large as the notch allows, up to 20 pt.
    private var artworkSize: Double { min(20, notchHeight - 8) }

    /// The gap the artwork leaves above and below; used on the sides too, so the
    /// artwork sits equally far from the side and the bottom of the notch.
    private var inset: Double { (notchHeight - artworkSize) / 2 }

    private var isPlaying: Bool { nowPlaying.track?.isPlaying == true }

    private var isBusy: Bool {
        junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
    }

    @ViewBuilder
    private var leading: some View {
        if isBusy {
            WingSpinner(size: artworkSize - 2)
                .frame(width: artworkSize, height: artworkSize)
                .transition(.opacity)
        } else if isPlaying {
            WingArtwork(image: nowPlaying.artwork, size: artworkSize, cornerRadius: max(3, NotchStyle.closedBottomRadius - inset))
                .transition(.scale(0.6).combined(with: .opacity))
        } else {
            WingRing(fraction: monitor.disk?.usedFraction ?? 0)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isPlaying {
            SoundBars(isPlaying: isPlaying)
                .transition(.opacity)
        } else {
            Text(monitor.disk.map { Self.compact($0.available) } ?? "")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(NotchStyle.level(monitor.disk?.usedFraction ?? 0))
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText())
                .transition(.opacity)
        }
    }

    /// `7,1G`, `13,6G`, `146G`: at most three digits, so it fits beside the camera
    /// housing (a fourth digit slid under it on the built-in display).
    static func compact(_ bytes: Int64) -> String {
        let units = ["K", "M", "G", "T"]
        var value = Double(bytes) / 1000
        var index = 0
        while value >= 999.5, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        let digits = value < 99.95 ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits)).locale(.cleen)) + units[index]
    }
}
