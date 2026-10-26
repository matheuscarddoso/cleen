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
    @Environment(AgentsModel.self) private var agents
    @Environment(RecorderModel.self) private var recorder
    @AppStorage(LiveActivitySettings.agentsKey) private var showsAgents = true
    @AppStorage(LiveActivitySettings.idleKey) private var idle = LiveActivitySettings.Idle.disk.rawValue

    var body: some View {
        if let since = recorder.recordingStart {
            RecordingWings(since: since, notchWidth: notchWidth, inset: inset)
                .transition(.opacity)
        } else if let banner = live.banner, banner.isIsland, case .downloaded(let url, let size) = banner {
            DownloadIsland(url: url, size: size, notchHeight: notchHeight)
                .id(banner)
                .transition(.trackSwap)
        } else if let banner = live.banner, !isBusy {
            LiveActivityBanner(activity: banner, notchWidth: notchWidth, inset: inset, artworkSize: artworkSize)
                .id(banner)
                .transition(.trackSwap)
        } else {
            wings.transition(.opacity)
        }
    }

    private var wings: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                // Claude first, even beside what's playing: it's what you're waiting on.
                if showsClaude {
                    ClaudeWingIndicator(isWorking: !agents.working.isEmpty, justFinished: agents.justFinished, needsApproval: !agents.approvals.isEmpty)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                leading
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, inset)
            Spacer(minLength: notchWidth)
            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, inset)
        }
        .frame(maxHeight: .infinity)
        .animation(NotchStyle.liveSpring, value: isPlaying)
        .animation(NotchStyle.liveSpring, value: nowPlaying.artwork.map(ObjectIdentifier.init))
        .animation(.smooth(duration: 0.3), value: live.meeting)
        .animation(.smooth(duration: 0.3), value: timer.isActive)
        .animation(NotchStyle.liveSpring, value: live.download?.id)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: showsClaude)
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

    /// A session working, or one that just finished (its check is still up). A request
    /// waiting for permission always shows: it's holding a session up.
    private var showsClaude: Bool {
        showsAgents && (!agents.working.isEmpty || agents.justFinished) || !agents.approvals.isEmpty
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
        } else if let download = live.download {
            DownloadRing(fraction: download.estimate.fraction, size: artworkSize)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
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
                .transition(.scale(0.7).combined(with: .opacity))
        }
        // Idle, the left wing stays empty: the reading and its bar are on the right.
    }

    private var batteryColor: Color {
        guard let battery = monitor.battery else { return NotchStyle.barFill }
        if battery.isCharging { return NotchStyle.good }
        return battery.level <= 0.2 ? NotchStyle.critical : NotchStyle.barFill
    }

    @ViewBuilder
    private var trailing: some View {
        if let download = live.download, !isBusy {
            wingText(DownloadText.remaining(download.estimate), color: NotchStyle.primary)
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
        } else if timer.isActive, !isBusy {
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
                let used = monitor.disk?.usedFraction ?? 0
                wingMeter(monitor.disk.map { Self.compact($0.available) } ?? "", fraction: used, color: NotchStyle.level(used))
            case .battery:
                wingMeter(monitor.battery?.level.percent ?? "", fraction: monitor.battery?.level ?? 0, color: batteryColor)
            case .cpu:
                let load = monitor.cpu?.total ?? 0
                wingMeter(monitor.cpu?.total.percent ?? "", fraction: load, color: NotchStyle.level(load))
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

    /// The idle reading with a hairline bar under it, as wide as the text: how full the
    /// disk is (or the battery, the CPU) without a ring taking the other wing.
    private func wingMeter(_ text: String, fraction: Double, color: Color) -> some View {
        wingText(text, color: color)
            .padding(.bottom, 4.5)
            .overlay(alignment: .bottom) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NotchStyle.track)
                        Capsule()
                            .fill(color)
                            .frame(width: max(2.5, proxy.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 2.5)
                .animation(.smooth(duration: 0.4), value: fraction)
            }
            .accessibilityValue(fraction.percent)
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
