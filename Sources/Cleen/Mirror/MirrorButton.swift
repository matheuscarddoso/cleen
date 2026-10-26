import AppKit
import SwiftUI

/// NotchNook's Mirror: a grey disc with a webcam glyph; once the camera is allowed it
/// becomes a live round mirror.
struct MirrorButton: View {
    /// 88 is the round mirror; wider makes it a pill.
    var width = 88.0
    @Environment(MirrorModel.self) private var mirror
    @Environment(NotchState.self) private var notch
    @State private var isHovered = false

    var body: some View {
        Button(action: tap) {
            ZStack {
                Capsule().fill(Color.white.opacity(isHovered ? 0.14 : 0.1))
                if mirror.access == .granted {
                    if notch.isEditingHome {
                        // Being arranged, it moves with its widget; there's nothing to grow.
                        CameraPreview(layer: mirror.previewLayer)
                            .clipShape(.capsule)
                    } else {
                        // The live preview is drawn over this spot by Início (MirrorSurface),
                        // so the same view can grow from here into the wide mirror.
                        Color.clear
                            .anchorPreference(key: MirrorFrameKey.self, value: .bounds) { $0 }
                    }
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: mirror.access == .denied ? "video.slash" : "web.camera")
                            .font(.system(size: 20, weight: .medium))
                        Text("Espelho")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(NotchStyle.primary.opacity(0.55))
                }
            }
            .frame(width: width, height: 88)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onAppear(perform: mirror.appear)
        .onDisappear(perform: mirror.disappear)
        .animation(.smooth(duration: 0.3), value: mirror.access)
        .help(help)
        .accessibilityLabel("Espelho")
    }

    /// How the mirror grows into the panel and back.
    static let grow = Animation.spring(response: 0.45, dampingFraction: 0.86)

    private var help: String {
        switch mirror.access {
        case .notAsked: String(localized: "Ver como você está antes de uma chamada")
        case .granted: String(localized: "Ampliar o espelho")
        case .denied: String(localized: "Permita a câmera em Ajustes do Sistema")
        }
    }

    private func tap() {
        switch mirror.access {
        case .notAsked:
            Task { await mirror.requestAccess() }
        case .denied:
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        case .granted:
            withAnimation(Self.grow) { notch.mirrorExpanded = true }
        }
    }
}
