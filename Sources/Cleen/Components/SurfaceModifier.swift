import SwiftUI

/// A quiet card: barely-there fill and a 1px hairline. No shadow; depth isn't needed
/// on a flat dark canvas and shadows muddy it.
struct SurfaceModifier: ViewModifier {
    var radius = Theme.Radius.large
    var padding = 16.0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.hairline)
            }
    }
}

extension View {
    func surface(radius: Double = Theme.Radius.large, padding: Double = 16) -> some View {
        modifier(SurfaceModifier(radius: radius, padding: padding))
    }
}
