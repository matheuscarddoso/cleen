import CoreGraphics
import SwiftUI

/// Bitmaps drawn once in code, so the onboarding paintings carry no image assets:
/// film grain for the canvas texture and a stippled veil that dissolves the painting
/// into the black card the way ink bleeds into paper.
nonisolated enum GrainTexture {
    /// Neutral grey noise, tiled over the paintings.
    static let noise: CGImage = makeNoise(side: 256)

    /// A handful of values, stretched over the whole painting: soft patches of light
    /// and shade, like paint laid on unevenly.
    static let clouds: CGImage = makeNoise(side: 14)

    /// Black on the left fading to clear on the right along an elliptical edge, with the
    /// edge broken into grains rather than a smooth gradient.
    static let veil: CGImage = makeVeil(width: 880, height: 540, scale: 2)

    /// Draws every bitmap ahead of time, off the main thread: the veil alone is two
    /// million pixels, and drawing it on first use stalled the step into the tour.
    static func prepare() {
        Task.detached(priority: .userInitiated) {
            _ = noise
            _ = clouds
            _ = veil
        }
    }

    private static func makeNoise(side: Int) -> CGImage {
        var generator = SplitMix(seed: 0x434C_4545_4E21)
        var pixels = [UInt8](repeating: 0, count: side * side)
        for index in pixels.indices {
            pixels[index] = UInt8(truncatingIfNeeded: generator.next() >> 56)
        }
        return grayImage(pixels, width: side, height: side)
    }

    private static func makeVeil(width: Int, height: Int, scale: Int) -> CGImage {
        let w = width * scale
        let h = height * scale
        var generator = SplitMix(seed: 0x5645_494C)
        // RGBA, premultiplied: black, so only alpha matters.
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let centerX = Double(w) * 1.12
        let centerY = Double(h) * 0.52
        let radiusX = Double(w) * 0.58
        let radiusY = Double(h) * 0.78
        for y in 0..<h {
            let dy = (Double(y) - centerY) / radiusY
            for x in 0..<w {
                let dx = (Double(x) - centerX) / radiusX
                let distance = (dx * dx + dy * dy).squareRoot()
                let fade = smoothstep(0.84, 1.06, distance)
                let alpha: Double
                if fade <= 0.001 {
                    alpha = 0
                } else if fade >= 0.999 {
                    alpha = 1
                } else {
                    // Stipple: each grain is either ink or not, weighted by the fade.
                    let roll = Double(generator.next() >> 11) / Double(1 << 53)
                    alpha = (roll < fade ? 0.92 : 0) + fade * 0.08
                }
                pixels[(y * w + x) * 4 + 3] = UInt8(alpha * 255)
            }
        }
        let context = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private static func grayImage(_ pixels: [UInt8], width: Int, height: Int) -> CGImage {
        var pixels = pixels
        let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return context.makeImage()!
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
