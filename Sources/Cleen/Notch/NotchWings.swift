import CleenKit
import SwiftUI

/// Live activity beside the closed notch, most important first: a scan or cleanup in
/// progress, a banner (power, headphones, a new song), a meeting about to start, what's
/// playing (artwork and moving bars, as NotchNook does), then the idle indicator the
/// person picked in Aparência (disk by default).
struct NotchWings: View {
    let notchWidth: Double
    let notchHeight: Double
    @Environment(SystemMonitor.self) private var monitor
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(LiveActivityCenter.self) private var live
    @Environment(TimerModel.self) private var timer
    @AppStorage(LiveActivitySettings.idleKey) private var idle = LiveActivitySettings.Idle.disk.rawValue

    var body: some View {
        if let banner = live.banner, !isBusy {
            LiveActivityBanner(activity: banner, notchWidth: notchWidth, inset: inset, artworkSize: artworkSize)
                .transition(.opacity)
        } else {
            wings.transition(.opacity)
        }
    }

    private var wings: some View {
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
        .animation(.smooth(duration: 0.3), value: live.meeting)
        .animation(.smooth(duration: 0.3), value: timer.isActive)
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

    private var idleIndicator: LiveActivitySettings.Idle {
        LiveActivitySettings.Idle(rawValue: idle) ?? .disk
    }

    @ViewBuilder
    private var leading: some View {
        if isBusy {
            WingSpinner(size: artworkSize - 2)
                .frame(width: artworkSize, height: artworkSize)
                .transition(.opacity)
        } else if timer.isActive {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                WingRing(fraction: 1 - timer.progress(at: context.date), color: timer.isRunning ? NotchStyle.warning : NotchStyle.secondary)
            }
            .transition(.opacity)
        } else if case .meeting(_, _, let color) = live.meeting {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(nsColor: color))
                .transition(.opacity)
        } else if isPlaying {
            WingArtwork(image: nowPlaying.artwork, size: artworkSize, cornerRadius: max(3, NotchStyle.closedBottomRadius - inset))
                .transition(.scale(0.6).combined(with: .opacity))
        } else {
            switch idleIndicator {
            case .disk: WingRing(fraction: monitor.disk?.usedFraction ?? 0).transition(.opacity)
            case .battery:
                WingRing(fraction: monitor.battery?.level ?? 0, color: batteryColor).transition(.opacity)
            case .cpu: WingRing(fraction: monitor.cpu?.total ?? 0).transition(.opacity)
            case .none: EmptyView()
            }
        }
    }

    private var batteryColor: Color {
        guard let battery = monitor.battery else { return NotchStyle.barFill }
        if battery.isCharging { return NotchStyle.good }
        return battery.level <= 0.2 ? NotchStyle.critical : NotchStyle.barFill
    }

    @ViewBuilder
    private var trailing: some View {
        if timer.isActive, !isBusy {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                wingText(TimerClock.string(timer.remaining(at: context.date)), color: timer.isRunning ? NotchStyle.primary : NotchStyle.secondary)
            }
            .transition(.opacity)
        } else if case .meeting(_, let start, _) = live.meeting, !isBusy {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                wingText(MeetingCountdown.text(until: start, now: context.date), color: NotchStyle.primary)
            }
            .transition(.opacity)
        } else if isPlaying {
            SoundBars(isPlaying: isPlaying)
                .transition(.opacity)
        } else {
            switch idleIndicator {
            case .disk:
                wingText(monitor.disk.map { Self.compact($0.available) } ?? "", color: NotchStyle.level(monitor.disk?.usedFraction ?? 0))
            case .battery:
                wingText(monitor.battery?.level.percent ?? "", color: batteryColor)
            case .cpu:
                wingText(monitor.cpu?.total.percent ?? "", color: NotchStyle.level(monitor.cpu?.total ?? 0))
            case .none: EmptyView()
            }
        }
    }

    private func wingText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .contentTransition(.numericText())
            .transition(.opacity)
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
