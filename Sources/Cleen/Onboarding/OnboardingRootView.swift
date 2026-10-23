import SwiftUI

/// The tour's panel: it grows out of the notch, plays the titles over a painting, then
/// splits into the page on the left and the painting with its illustration on the
/// right, and at the end folds back into the notch.
struct OnboardingRootView: View {
    let panelSize: CGSize
    let notchSize: CGSize
    @Environment(OnboardingModel.self) private var model

    static let illustrationWidth = 400.0
    static let topRadius = 18.0
    static let bottomRadius = 40.0

    private var isOpen: Bool { model.phase == .titles || model.phase == .tour }
    private var inTour: Bool { model.phase == .tour }

    var body: some View {
        card
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var shape: NotchShape {
        isOpen
            ? NotchShape(topRadius: Self.topRadius, bottomRadius: Self.bottomRadius)
            : NotchShape(topRadius: NotchStyle.closedTopRadius, bottomRadius: NotchStyle.closedBottomRadius)
    }

    private var card: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            painting
            veil
            illustration
            OnboardingTitles()
                .opacity(model.phase == .titles ? 1 : 0)
            page
            if model.phase == .titles {
                // Concentric with the panel's bottom corner: the capsule's radius plus the
                // gap equals the corner's, on the side and below alike.
                TitleControls()
                    .padding(.bottom, Self.bottomRadius - TitleControls.height / 2)
                    .padding(.trailing, Self.topRadius + Self.bottomRadius - TitleControls.height / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .transition(.opacity)
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .frame(width: isOpen ? panelSize.width : notchSize.width, height: isOpen ? panelSize.height : notchSize.height, alignment: .top)
        .clipShape(shape)
        .overlay { shape.stroke(.white.opacity(isOpen ? 0.1 : 0), lineWidth: 1) }
        .background { shape.fill(.black).shadow(color: .black.opacity(isOpen ? 0.55 : 0), radius: 40, y: 20) }
        .opacity(model.phase == .leaving ? 0.0 : 1)
        .animation(.easeIn(duration: 0.25).delay(0.35), value: model.phase == .leaving)
    }

    // MARK: Layers

    private var palette: PaintPalette { inTour ? model.step.palette : .dusk }

    private var painting: some View {
        ZStack {
            OnboardingPainting(palette: palette)
                .id(inTour ? model.step.rawValue : -1)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 1.1), value: model.step)
        .opacity(model.beat >= .painting && model.phase != .leaving ? 1 : 0)
    }

    /// Dissolves the painting into the black on the left, where the page sits.
    private var veil: some View {
        Image(decorative: GrainTexture.veil, scale: 2)
            .resizable()
            .opacity(inTour ? 1 : 0)
            .scaleEffect(x: inTour ? 1 : 0.4, anchor: .leading)
            .animation(.smooth(duration: 1.2), value: inTour)
            .allowsHitTesting(false)
    }

    private var illustration: some View {
        ZStack {
            if inTour {
                Group {
                    switch model.step {
                    case .welcome: WelcomeIllustration()
                    case .disk: DiskIllustration()
                    case .agenda: AgendaIllustration()
                    case .clipboard: ClipboardIllustration()
                    case .tabs: TabsIllustration()
                    case .shortcut: ShortcutIllustration()
                    case .done: DoneIllustration()
                    }
                }
                .id(model.step)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)).animation(.smooth(duration: 0.8).delay(0.2)),
                    removal: .opacity.combined(with: .scale(scale: 1.03)).animation(.smooth(duration: 0.35))
                ))
            }
        }
        // The painting's side only: never under the page's controls.
        .frame(width: Self.illustrationWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 22)
    }

    private var page: some View {
        ZStack(alignment: .topLeading) {
            if inTour {
                Group {
                    switch model.step {
                    case .welcome: WelcomeStep()
                    case .disk: DiskStep()
                    case .agenda: AgendaStep()
                    case .clipboard: ClipboardStep()
                    case .tabs: TabsStep()
                    case .shortcut: ShortcutStep()
                    case .done: DoneStep()
                    }
                }
                .id(model.step)
                .transition(.asymmetric(
                    insertion: .identity,
                    removal: .opacity.combined(with: .offset(x: model.movingBack ? 14 : -14)).animation(.smooth(duration: 0.25))
                ))
            }
        }
        .frame(width: 372)
        .padding(.leading, 56)
        .padding(.top, 58)
        .padding(.bottom, 46)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}
