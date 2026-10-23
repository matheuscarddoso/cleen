import SwiftUI

/// "hello" in one continuous monoline stroke, the way Apple writes it: drawn by
/// trimming the path from start to end. A smooth curve through hand-placed points
/// (Catmull–Rom), so it reads as handwriting and never as a typeface.
struct HelloLettering: Shape {
    /// Centerline points on a 72 × 32 grid: baseline at y 30, x-height at 18.
    private static let points: [CGPoint] = [
        // h: lead-in, the tall loop, down the stem, the hump.
        (0, 29), (5, 24), (10, 15), (13.5, 6), (13, 1.5), (10.5, 2.5), (9.5, 10), (8.6, 20), (8, 30),
        (9.6, 24.5), (13, 19.5), (16.6, 18), (18.8, 20.6), (19, 26), (20.4, 29.6),
        // e
        (24.5, 28.6), (29.6, 25), (32.2, 21.2), (31.4, 18.2), (28.6, 18.4), (26.2, 21.6), (26.2, 26.4), (29.2, 29.8), (34, 29.8),
        // l
        (38.2, 26), (41.8, 16.4), (44.4, 6.4), (43.6, 1.4), (40.8, 2.4), (39, 10.4), (38.2, 20.4), (39, 28.2), (42, 29.8),
        // l
        (46.2, 26), (49.8, 16.4), (52.4, 6.4), (51.6, 1.4), (48.8, 2.4), (47, 10.4), (46.2, 20.4), (47, 28.2), (50, 29.8),
        // o, and its little tail
        (54, 28), (56.6, 22.4), (60.2, 18.4), (64, 18.4), (66.2, 22), (65.2, 27), (61.4, 30), (57.6, 28.4), (58.2, 23.4),
        (62, 20.2), (67, 19.2), (72, 20),
    ].map { CGPoint(x: $0.0, y: $0.1) }

    static let aspectRatio = 72.0 / 32.0

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 72, rect.height / 32)
        let offset = CGPoint(x: rect.minX + (rect.width - 72 * scale) / 2, y: rect.minY + (rect.height - 32 * scale) / 2)
        let points = Self.points.map { CGPoint(x: offset.x + $0.x * scale, y: offset.y + $0.y * scale) }
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 0..<(points.count - 1) {
            let p0 = points[max(0, index - 1)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(points.count - 1, index + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}
