import SwiftUI

/// Live activity beside the closed notch. While something plays: its artwork on the
/// left of the camera, moving sound bars on the right (as NotchNook does). Otherwise:
/// disk fullness and free space. During a scan or cleanup: progress.
struct NotchWings: View {
    let notchWidth: Double
    @Environment(SystemMonitor.self) private var monitor
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app
    @Environment(NowPlayingModel.self) private var nowPlaying

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            Spacer(minLength: notchWidth)
            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity)
        .animation(.smooth(duration: 0.3), value: isPlaying)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cleen")
    }

    private var isPlaying: Bool { nowPlaying.track?.isPlaying == true }

    private var isBusy: Bool {
        junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
    }

    @ViewBuilder
    private var leading: some View {
        if isBusy {
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
        } else if isPlaying {
            WingArtwork(image: nowPlaying.artwork)
                .transition(.scale(0.6).combined(with: .opacity))
        } else {
            WingRing(fraction: monitor.disk?.usedFraction ?? 0)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isPlaying {
            SoundBars(tint: nowPlaying.tint.map { Color(nsColor: $0).mix(with: .white, by: 0.55) } ?? .white)
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

    /// `7,1 GB` → `7,1G`: the wing is small.
    static func compact(_ bytes: Int64) -> String {
        // The formatter may separate the unit with a no-break space; \s covers both.
        bytes.bytes.replacing(/\s*([KMGT])B/, with: { $0.output.1 })
    }
}
