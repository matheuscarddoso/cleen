import SwiftUI

/// A painterly landscape: a mesh gradient with a low light on the horizon, brushed with
/// horizontal streaks and film grain so it reads as paint on canvas, not a gradient.
struct OnboardingPainting: View {
    let palette: PaintPalette

    /// Still, like a canvas: the layers are flattened into one image once, so nothing
    /// is re-blended while the pages move over it.
    var body: some View {
        MeshGradient(width: 3, height: 4, points: Self.points, colors: palette.meshColors, smoothsColors: true)
            .overlay { mottling }
            .overlay { streaks }
            .overlay { grain }
            .drawingGroup()
    }

    /// The horizon sits a little above centre, the light right of it.
    private static let points: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.39], [0.63, 0.43], [1, 0.36],
        [0, 0.69], [0.57, 0.67], [1, 0.72],
        [0, 1], [0.5, 1], [1, 1],
    ]

    /// Patches of thicker and thinner paint: the grain blown up and blurred into
    /// soft clouds.
    private var mottling: some View {
        Image(decorative: GrainTexture.clouds, scale: 1)
            .resizable()
            .interpolation(.high)
            .blur(radius: 14)
            .blendMode(.softLight)
            .opacity(0.55)
            .allowsHitTesting(false)
    }

    /// Brush strokes: the grain stretched sideways and softened, barely there.
    private var streaks: some View {
        Image(decorative: GrainTexture.noise, scale: 1)
            .resizable(resizingMode: .tile)
            .frame(width: 140, height: 540)
            .scaleEffect(x: 9, y: 1, anchor: .leading)
            .blur(radius: 0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .blendMode(.softLight)
            .opacity(0.16)
            .clipped()
            .allowsHitTesting(false)
    }

    private var grain: some View {
        Image(decorative: GrainTexture.noise, scale: 2)
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(0.1)
            .allowsHitTesting(false)
    }
}
