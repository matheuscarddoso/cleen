import SwiftUI

/// Fills the notch panel window. The black shape hangs from the top center and morphs
/// between the closed notch (with its live-activity wings) and the open panel.
struct NotchRootView: View {
    let controller: NotchController
    @Environment(NotchState.self) private var state
    @AppStorage(NotchSettings.showsWingsKey) private var showsWings = true
    @AppStorage(LiveActivitySettings.idleKey) private var idle = LiveActivitySettings.Idle.disk.rawValue
    @AppStorage(LiveActivitySettings.hideInFullscreenKey) private var hidesInFullscreen = true
    @Environment(LiveActivityCenter.self) private var live
    @Environment(FullscreenWatcher.self) private var fullscreen
    @Environment(NowPlayingModel.self) private var nowPlaying
    @Environment(JunkModel.self) private var junk
    @Environment(AppModel.self) private var app
    @Environment(TimerModel.self) private var timer
    @Environment(AgentsModel.self) private var agents

    var body: some View {
        if let geometry = state.geometry {
            let closed = geometry.closedSize(wingWidth: wingWidth)
            let size = state.isOpen ? geometry.openSize : closed
            let shape = NotchShape(
                topRadius: state.isOpen ? NotchStyle.openTopRadius : NotchStyle.closedTopRadius,
                bottomRadius: state.isOpen ? NotchStyle.openBottomRadius : NotchStyle.closedBottomRadius
            )

            ZStack(alignment: .top) {
                // Content is laid out at its final size, never squeezed by the moving
                // shape: the shape only reveals and hides it.
                if state.isOpen {
                    NotchOpenContent(controller: controller, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.openTopRadius)
                        .frame(width: geometry.openSize.width, height: geometry.openSize.height, alignment: .top)
                        .transition(.notchPanel)
                } else if wingWidth > 0 {
                    NotchWings(notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.closedTopRadius)
                        .frame(width: closed.width, height: closed.height)
                        .transition(.notchWings)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(NotchStyle.background)
            .clipShape(shape)
            .background {
                shape
                    .fill(NotchStyle.background)
                    .shadow(color: .black.opacity(state.isOpen ? 0.55 : 0), radius: 22, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: wingWidth)
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        }
    }

    /// How far the closed notch reaches past the camera on each side: wide for a
    /// banner, the usual wing when there's something to show, none otherwise (also
    /// during full screen, unless the person wants the wings there).
    private var wingWidth: Double {
        guard showsWings else { return 0 }
        if hidesInFullscreen, fullscreen.isFullscreen(controller.screen) { return 0 }
        let busy = junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
        if live.banner != nil, !busy { return LiveActivity.bannerWingWidth }
        let hasContent = busy || timer.isActive || live.meeting != nil || (LiveActivitySettings.agents && !agents.working.isEmpty) || nowPlaying.track?.isPlaying == true
            || LiveActivitySettings.Idle(rawValue: idle) != LiveActivitySettings.Idle.none
        return hasContent ? NotchGeometry.wingWidth : 0
    }
}
