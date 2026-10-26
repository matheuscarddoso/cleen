import CoreGraphics
import Foundation

/// Screen Studio's camera shape: a square whose corners are superellipse quarters
/// (|x|ⁿ + |y|ⁿ = 1, n = 2.6), each taking 19.4% of the side. Measured off its camera
/// preview (a 240 pt square, corners 46.5 pt deep); a circle or Apple's continuous
/// corner of any radius follows that edge less closely.
public enum Squircle {
    public static let cornerFraction = 0.194
    public static let exponent = 2.6

    public static func path(in rect: CGRect, cornerFraction: Double = cornerFraction, exponent: Double = exponent, steps: Int = 24) -> CGPath {
        let a = min(rect.width, rect.height) * cornerFraction
        let path = CGMutablePath()
        // One corner's curve, from the end of one edge to the start of the next,
        // around `center` (the corner box's inner corner), turning through `quadrant`.
        func corner(center: CGPoint, sx: CGFloat, sy: CGFloat, reversed: Bool) {
            for i in 0...steps {
                let t = Double(reversed ? steps - i : i) / Double(steps) * .pi / 2
                let x = a * pow(cos(t), 2 / exponent)
                let y = a * pow(sin(t), 2 / exponent)
                let point = CGPoint(x: center.x + sx * x, y: center.y + sy * y)
                if path.isEmpty { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
        // Clockwise in a top-left-origin rect: top-left, top-right, bottom-right, bottom-left.
        corner(center: CGPoint(x: rect.minX + a, y: rect.minY + a), sx: -1, sy: -1, reversed: false)
        corner(center: CGPoint(x: rect.maxX - a, y: rect.minY + a), sx: 1, sy: -1, reversed: true)
        corner(center: CGPoint(x: rect.maxX - a, y: rect.maxY - a), sx: 1, sy: 1, reversed: false)
        corner(center: CGPoint(x: rect.minX + a, y: rect.maxY - a), sx: -1, sy: 1, reversed: true)
        path.closeSubpath()
        return path
    }
}
