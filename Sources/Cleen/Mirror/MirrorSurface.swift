import SwiftUI

/// The live mirror on Início: one view for both the round mirror and the wide one, laid
/// over the round button and grown to fill the panel when tapped.
///
/// One view, never two: the camera has a single preview layer, and handing it from the
/// round view to a separate wide one mid-animation showed the wide frame at once,
/// already big, instead of growing out of the circle. Here only the frame and the
/// corners animate.
struct MirrorSurface: View {
    /// Concentric with the panel when wide: its bottom corner radius minus the 20 pt inset.
    static let wideRadius = NotchStyle.openBottomRadius - NotchOpenContent.inset

    /// The round mirror's place, in the tab's space; nil until it has been laid out.
    let circle: CGRect?
    /// The tab's whole area.
    let area: CGRect
    @Environment(MirrorModel.self) private var mirror
    @Environment(NotchState.self) private var notch
    /// The last place the round mirror had: while the panel is wide the row is gone,
    /// and shrinking back aims for where it was.
    @State private var lastCircle: CGRect?

    var body: some View {
        let expanded = notch.mirrorExpanded
        if let target = expanded ? wide : (circle ?? lastCircle) {
            let radius = expanded ? Self.wideRadius : min(target.width, target.height) / 2
            CameraPreview(layer: mirror.previewLayer)
                .clipShape(.rect(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(NotchStyle.cardStroke)
                        .opacity(expanded ? 1 : 0)
                }
                .frame(width: target.width, height: target.height)
                .position(x: target.midX, y: target.midY)
                .contentShape(.rect)
                // Round, the button underneath takes the click (and shows the hover).
                .allowsHitTesting(expanded)
                .onTapGesture { withAnimation(MirrorButton.grow) { notch.mirrorExpanded = false } }
                .onAppear(perform: mirror.appear)
                .onDisappear(perform: mirror.disappear)
                .help(expanded ? String(localized: "Clique para voltar") : "")
                .accessibilityHidden(!expanded)
                .accessibilityLabel("Espelho")
                .accessibilityAddTraits(.isButton)
                .onChange(of: circle, initial: true) { _, rect in
                    if let rect { lastCircle = rect }
                }
        }
    }

    /// The panel's width, with the same gap at the bottom as on the sides.
    private var wide: CGRect {
        CGRect(x: area.minX, y: area.minY, width: area.width, height: max(0, area.height - NotchOpenContent.inset))
    }
}
