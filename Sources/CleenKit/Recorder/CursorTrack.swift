import CoreGraphics
import Foundation

/// Where the pointer was during a recording, and where it clicked, in the recorded
/// area's own coordinates: 0…1 across and down, top-left origin. The system cursor is
/// left out of the video; the editor draws its own, smoothed, from this.
public struct CursorTrack: Codable, Sendable, Equatable {
    public struct Sample: Codable, Sendable, Equatable {
        /// Seconds from the start of the recording.
        public let t: Double
        public let x: Double
        public let y: Double

        public init(t: Double, x: Double, y: Double) {
            self.t = t
            self.x = x
            self.y = y
        }
    }

    public struct Click: Codable, Sendable, Equatable {
        public let t: Double
        public let x: Double
        public let y: Double

        public init(t: Double, x: Double, y: Double) {
            self.t = t
            self.x = x
            self.y = y
        }
    }

    /// The pointer's shape: the arrow, the hand over a link, the text cursor…
    public enum Shape: String, Codable, Sendable, CaseIterable {
        case arrow, pointingHand, iBeam, openHand, closedHand, crosshair, resizeLeftRight, resizeUpDown, notAllowed
    }

    /// When the shape changed to what.
    public struct ShapeChange: Codable, Sendable, Equatable {
        public let t: Double
        public let shape: Shape

        public init(t: Double, shape: Shape) {
            self.t = t
            self.shape = shape
        }
    }

    public var samples: [Sample]
    public var clicks: [Click]
    public var shapes: [ShapeChange]

    public init(samples: [Sample] = [], clicks: [Click] = [], shapes: [ShapeChange] = []) {
        self.samples = samples
        self.clicks = clicks
        self.shapes = shapes
    }

    private enum CodingKeys: String, CodingKey { case samples, clicks, shapes }

    /// Tracks recorded before shapes were kept open as all arrow.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        samples = try c.decodeIfPresent([Sample].self, forKey: .samples) ?? []
        clicks = try c.decodeIfPresent([Click].self, forKey: .clicks) ?? []
        shapes = try c.decodeIfPresent([ShapeChange].self, forKey: .shapes) ?? []
    }

    /// The shape at `t`: the last change before it.
    public func shape(at t: Double) -> Shape {
        var low = 0, high = shapes.count
        while low < high {
            let mid = (low + high) / 2
            if shapes[mid].t <= t { low = mid + 1 } else { high = mid }
        }
        return low > 0 ? shapes[low - 1].shape : .arrow
    }

    /// The raw position at `t`, between the two samples around it.
    public func position(at t: Double) -> CGPoint? {
        Self.interpolate(samples.map { ($0.t, $0.x, $0.y) }, at: t)
    }

    /// Linear interpolation over time-sorted points; clamps outside their span.
    static func interpolate(_ points: [(Double, Double, Double)], at t: Double) -> CGPoint? {
        guard let first = points.first, let last = points.last else { return nil }
        if t <= first.0 { return CGPoint(x: first.1, y: first.2) }
        if t >= last.0 { return CGPoint(x: last.1, y: last.2) }
        var low = 0, high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].0 <= t { low = mid } else { high = mid }
        }
        let a = points[low], b = points[high]
        let span = b.0 - a.0
        let f = span > 0 ? (t - a.0) / span : 0
        return CGPoint(x: a.1 + (b.1 - a.1) * f, y: a.2 + (b.2 - a.2) * f)
    }
}

/// The pointer's path as the editor shows it: the recorded one run through a critically
/// damped spring, so jitter and jumps become a glide, like Screen Studio's cursor.
/// Built once per smoothing value; looking a time up is a binary search.
public struct CursorPath: Sendable {
    private let points: [(Double, Double, Double)]

    /// `smoothing` 0 follows the pointer exactly; 1 glides the most.
    public init(track: CursorTrack, smoothing: Double, step: Double = 1.0 / 240) {
        guard let first = track.samples.first, let last = track.samples.last else {
            points = []
            return
        }
        let smoothing = min(1, max(0, smoothing))
        guard smoothing > 0.001 else {
            points = track.samples.map { ($0.t, $0.x, $0.y) }
            return
        }
        // Angular frequency: high follows tightly, low lags and glides.
        let omega = 40 - 34 * smoothing
        var x = first.x, y = first.y, vx = 0.0, vy = 0.0
        var result: [(Double, Double, Double)] = [(first.t, x, y)]
        result.reserveCapacity(Int((last.t - first.t) / step) + 2)
        let raw = track.samples.map { ($0.t, $0.x, $0.y) }
        var t = first.t
        while t < last.t {
            t += step
            guard let target = CursorTrack.interpolate(raw, at: t) else { break }
            // Critically damped spring, semi-implicit Euler.
            let ax = omega * omega * (target.x - x) - 2 * omega * vx
            let ay = omega * omega * (target.y - y) - 2 * omega * vy
            vx += ax * step
            vy += ay * step
            x += vx * step
            y += vy * step
            result.append((t, x, y))
        }
        points = result
    }

    public func position(at t: Double) -> CGPoint? {
        CursorTrack.interpolate(points, at: t)
    }

    public var isEmpty: Bool { points.isEmpty }
}
