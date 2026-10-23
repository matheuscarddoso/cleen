import SwiftUI

/// The four tones of one painted landscape: a dark sky, the haze above the horizon,
/// the light breaking through it, and the ground.
struct PaintPalette: Equatable {
    let sky: Color
    let haze: Color
    let glow: Color
    let ground: Color

    /// A 3 × 4 mesh, top row first: the light sits right of centre, like a low sun.
    var meshColors: [Color] {
        [
            sky, sky, sky.mix(with: haze, by: 0.25),
            sky.mix(with: haze, by: 0.55), haze, haze.mix(with: glow, by: 0.35),
            haze.mix(with: glow, by: 0.35), glow, glow.mix(with: haze, by: 0.25),
            ground, ground.mix(with: haze, by: 0.2), ground,
        ]
    }

    static let dusk = PaintPalette(sky: Color(hex: 0x111419), haze: Color(hex: 0x3B4350), glow: Color(hex: 0xC8BCB6), ground: Color(hex: 0x24252A))
    static let forest = PaintPalette(sky: Color(hex: 0x0C1412), haze: Color(hex: 0x2B403B), glow: Color(hex: 0x8FA79C), ground: Color(hex: 0x18201D))
    static let dawn = PaintPalette(sky: Color(hex: 0x2B1C18), haze: Color(hex: 0x9A5E46), glow: Color(hex: 0xF0C9A4), ground: Color(hex: 0x4A3328))
    static let night = PaintPalette(sky: Color(hex: 0x0C0D1C), haze: Color(hex: 0x2C2F5E), glow: Color(hex: 0x8D90D0), ground: Color(hex: 0x15162A))
    static let sage = PaintPalette(sky: Color(hex: 0x12140E), haze: Color(hex: 0x434A31), glow: Color(hex: 0xB9BF94), ground: Color(hex: 0x23261B))
    static let plum = PaintPalette(sky: Color(hex: 0x160F17), haze: Color(hex: 0x4D2C4B), glow: Color(hex: 0xC792AD), ground: Color(hex: 0x241724))
    static let sunrise = PaintPalette(sky: Color(hex: 0x1D140B), haze: Color(hex: 0x7A4C1C), glow: Color(hex: 0xF6CF73), ground: Color(hex: 0x3A2812))
}
