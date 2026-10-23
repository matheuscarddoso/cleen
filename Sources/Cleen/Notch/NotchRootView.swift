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
    @Environment(MediaKeyHUD.self) private var mediaKeys

    var body: some View {
        if let geometry = state.geometry {
            let closed = geometry.closedSize(wingWidth: wingWidth)
            let welcomes = state.isOpen && state.showsWelcome
            let size = state.isOpen ? (welcomes ? geometry.welcomeSize : geometry.openSize) : closed
            let shape = NotchShape(
                topRadius: state.isOpen ? NotchStyle.openTopRadius : NotchStyle.closedTopRadius,
                bottomRadius: state.isOpen ? (welcomes ? 26 : NotchStyle.openBottomRadius) : NotchStyle.closedBottomRadius
            )

            ZStack(alignment: .top) {
                // Content is laid out at its final size, never squeezed by the moving
                // shape: the shape only reveals and hides it.
                if welcomes {
                    WelcomeNotch(controller: controller)
                        .padding(.top, geometry.notchSize.height + 6)
                        .frame(width: geometry.welcomeSize.width, height: geometry.welcomeSize.height, alignment: .top)
                        .transition(.notchPanel)
                } else if state.isOpen {
                    NotchOpenContent(controller: controller, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.openTopRadius)
                        .frame(width: geometry.openSize.width, height: geometry.openSize.height, alignment: .top)
                        .transition(state.opensInstantly ? .identity : .notchPanel)
                } else if let reading = mediaKeys.reading(on: controller.screen) {
                    MediaKeyHUDWings(reading: reading, notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.closedTopRadius)
                        .frame(width: closed.width, height: closed.height)
                        .transition(.opacity.animation(.smooth(duration: 0.2)))
                } else if wingWidth > 0 {
                    NotchWings(notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.closedTopRadius)
                        .frame(width: closed.width, height: closed.height)
                        .transition(state.opensInstantly ? .identity : .notchWings)
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
            .overlay(alignment: .top) {
                if state.isOpen, !welcomes, let reading = mediaKeys.reading(on: controller.screen) {
                    MediaKeyHUDPill(reading: reading)
                        .padding(.top, geometry.notchSize.height + 4)
                        .transition(.scale(0.85, anchor: .top).combined(with: .opacity).animation(.spring(response: 0.36, dampingFraction: 0.84)))
                }
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
        // Volume and brightness stand in for the system's display, so they show even
        // with the wings off or in full screen.
        if mediaKeys.reading(on: controller.screen) != nil { return MediaKeyHUD.wingWidth }
        guard showsWings else { return 0 }
        if hidesInFullscreen, fullscreen.isFullscreen(controller.screen) { return 0 }
        let busy = junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
        if live.banner != nil, !busy { return LiveActivity.bannerWingWidth }
        let claude = LiveActivitySettings.agents && (!agents.working.isEmpty || agents.justFinished)
        let hasContent = busy || timer.isActive || live.meeting != nil || claude || nowPlaying.track?.isPlaying == true
            || LiveActivitySettings.Idle(rawValue: idle) != LiveActivitySettings.Idle.none
        // Claude's glyph sits before whatever else is on the left wing.
        return hasContent ? NotchGeometry.wingWidth + (claude ? 20 : 0) : 0
    }
}
