import SwiftUI

/// The mirror at full width, grown out of the round button. Tap to shrink it back.
struct MirrorExpanded: View {
    let namespace: Namespace.ID
    @Environment(MirrorModel.self) private var mirror
    @Environment(NotchState.self) private var notch

    var body: some View {
        CameraPreview(session: mirror.camera.session)
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
            .matchedGeometryEffect(id: "mirror", in: namespace)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NotchStyle.cardStroke)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .onTapGesture { notch.mirrorExpanded = false }
            .onAppear(perform: mirror.appear)
            .onDisappear(perform: mirror.disappear)
            .help("Clique para voltar")
            .accessibilityLabel("Espelho")
            .accessibilityAddTraits(.isButton)
    }
}
