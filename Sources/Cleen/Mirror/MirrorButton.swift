import AppKit
import SwiftUI

/// NotchNook's Mirror: a grey disc with a webcam glyph; once the camera is allowed it
/// becomes a live round mirror.
struct MirrorButton: View {
    let namespace: Namespace.ID
    @Environment(MirrorModel.self) private var mirror
    @Environment(NotchState.self) private var notch
    @State private var isHovered = false

    var body: some View {
        Button(action: tap) {
            ZStack {
                Circle().fill(Color.white.opacity(isHovered ? 0.14 : 0.1))
                if mirror.access == .granted {
                    CameraPreview(session: mirror.camera.session)
                        .clipShape(.rect(cornerRadius: 44, style: .continuous))
                        .matchedGeometryEffect(id: "mirror", in: namespace)
                        .transition(.opacity)
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
            .frame(width: 88, height: 88)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onAppear(perform: mirror.appear)
        .onDisappear(perform: mirror.disappear)
        .animation(.smooth(duration: 0.3), value: mirror.access)
        .help(help)
        .accessibilityLabel("Espelho")
    }

    private var help: String {
        switch mirror.access {
        case .notAsked: "Ver como você está antes de uma chamada"
        case .granted: "Ampliar o espelho"
        case .denied: "Permita a câmera em Ajustes do Sistema"
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
            notch.mirrorExpanded = true
        }
    }
}
