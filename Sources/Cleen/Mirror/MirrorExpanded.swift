import SwiftUI

/// The mirror at full width, grown out of the round button. Tap to shrink it back.
struct MirrorExpanded: View {
    /// Concentric with the panel: its bottom corner radius minus the 20 pt inset.
    static let radius = NotchStyle.openBottomRadius - NotchOpenContent.inset

    let namespace: Namespace.ID
    @Environment(MirrorModel.self) private var mirror
    @Environment(NotchState.self) private var notch

    var body: some View {
        CameraPreview(layer: mirror.previewLayer)
            .clipShape(.rect(cornerRadius: Self.radius, style: .continuous))
            .matchedGeometryEffect(id: "mirror", in: namespace)
            .overlay {
                RoundedRectangle(cornerRadius: Self.radius, style: .continuous).strokeBorder(NotchStyle.cardStroke)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Same gap at the bottom as on the sides.
            .padding(.bottom, NotchOpenContent.inset)
            .contentShape(.rect)
            .onTapGesture { notch.mirrorExpanded = false }
            .onAppear(perform: mirror.appear)
            .onDisappear(perform: mirror.disappear)
            .help("Clique para voltar")
            .accessibilityLabel("Espelho")
            .accessibilityAddTraits(.isButton)
    }
}
