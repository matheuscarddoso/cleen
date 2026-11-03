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
    @Environment(RecorderModel.self) private var recorder
    @Environment(CallMonitor.self) private var calls
    @Environment(IncomingCallWatcher.self) private var incoming

    var body: some View {
        if let geometry = state.geometry {
            let island = !state.isOpen && (live.banner?.isIsland == true || incoming.ringing != nil) && !recorder.isRecording
            let closed = island
                ? CGSize(width: geometry.notchSize.width + LiveActivity.islandWingWidth * 2, height: geometry.notchSize.height + LiveActivity.islandExtraHeight)
                : geometry.closedSize(wings(geometry))
            let welcomes = state.isOpen && state.showsWelcome
            // The teleprompter reading: the panel is all script, an arc of light behind it.
            let prompting = state.isOpen && state.isPrompting && state.tab == .teleprompter && !welcomes && !state.showsSearch && !state.showsSettings
            let open = geometry.openSize(state.panelHeight)
            let size = state.isOpen ? (welcomes ? geometry.welcomeSize : open) : closed
            let shape = NotchShape(
                topRadius: state.isOpen ? NotchStyle.openTopRadius : NotchStyle.closedTopRadius,
                bottomRadius: state.isOpen ? (welcomes ? 26 : NotchStyle.openBottomRadius) : (island ? 24 : NotchStyle.closedBottomRadius)
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
                        .frame(width: open.width, height: open.height, alignment: .top)
                        .transition(state.opensInstantly ? .identity : .notchPanel)
                } else if let reading = mediaKeys.reading(on: controller.screen) {
                    MediaKeyHUDWings(reading: reading, notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height)
                        .padding(.horizontal, NotchStyle.closedTopRadius)
                        .frame(width: closed.width, height: closed.height)
                        .transition(.opacity.animation(.smooth(duration: 0.2)))
                } else if !wings(geometry).isEmpty {
                    NotchWings(notchWidth: geometry.notchSize.width, notchHeight: geometry.notchSize.height, wings: wings(geometry))
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
            // Wings of different widths: the camera stays where it is, the notch around it
            // reaches further on the side with more to show. Open, it's centred again.
            .offset(x: state.isOpen || island ? 0 : wings(geometry).offset)

            // The tabs' dock, floating under the panel.
            .overlay(alignment: .top) {
                if state.showsTabDock {
                    NotchTabBar(maxWidth: NotchTabBar.maxWidth(panelWidth: open.width))
                        .offset(y: size.height + NotchGeometry.dockGap)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity).animation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.06)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        ))
                }
            }
            .overlay(alignment: .top) {
                if state.isOpen, !welcomes, let reading = mediaKeys.reading(on: controller.screen) {
                    MediaKeyHUDPill(reading: reading)
                        .padding(.top, geometry.notchSize.height + 4)
                        .transition(.scale(0.85, anchor: .top).combined(with: .opacity).animation(.spring(response: 0.36, dampingFraction: 0.84)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(NotchStyle.liveSpring, value: wings(geometry))
            .onChange(of: wings(geometry), initial: true) { _, wings in
                if state.closedWings != wings { state.closedWings = wings }
            }

            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
        }
    }

    /// How far the closed notch reaches past the camera on each side: wide for a
    /// banner, exactly as wide as their content for the everyday wings, none otherwise
    /// (also during full screen, unless the person wants the wings there).
    private func wings(_ geometry: NotchGeometry) -> ClosedWings {
        // Volume and brightness stand in for the system's display, so they show even
        // with the wings off or in full screen.
        if mediaKeys.reading(on: controller.screen) != nil { return .symmetric(MediaKeyHUD.wingWidth) }
        // A recording always shows, wings on or off: it's how you know it's running.
        if recorder.isRecording { return .symmetric(NotchGeometry.wingWidth) }
        // A finished download is worth showing even with the wings off.
        if live.banner?.isIsland == true || incoming.ringing != nil { return .symmetric(LiveActivity.islandWingWidth) }
        // A call too: the time and the voice, like the phone's island.
        if calls.call != nil { return .symmetric(NotchGeometry.wingWidth + 22) }
        guard showsWings else { return .none }
        if hidesInFullscreen, fullscreen.isFullscreen(controller.screen) { return .none }
        let busy = junk.phase == .scanning || junk.isCleaning || app.isSmartScanning || app.isSmartCleaning
        if live.banner != nil, !busy { return .symmetric(LiveActivity.bannerWingWidth) }
        let claude = agents.wing(showingSessions: LiveActivitySettings.agents) != nil
        let hasContent = busy || timer.isActive || live.meeting != nil || live.download != nil || claude || nowPlaying.track?.isPlaying == true
            || LiveActivitySettings.Idle(rawValue: idle) != LiveActivitySettings.Idle.none
        guard hasContent else { return .none }
        // Each wing fits what `NotchWings` measured in it; until it has measured (the
        // first frame), the usual wing on both sides.
        let content = state.wingContent
        guard content.isMeasured else { return .symmetric(NotchGeometry.wingWidth) }
        return ClosedWings(leading: geometry.wingWidth(fitting: content.leading), trailing: geometry.wingWidth(fitting: content.trailing))
    }
}
