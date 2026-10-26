import CoreGraphics
import Foundation

/// A stretch of the recording shown closer: the editor's zoom blocks on the timeline.
public struct ZoomSegment: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var start: Double
    public var end: Double
    /// 1 is the whole recording; 2 shows half of it across.
    public var scale: Double
    /// A fixed point to look at (0…1); nil follows the pointer, as Screen Studio does.
    public var focus: CGPoint?

    public init(id: UUID = UUID(), start: Double, end: Double, scale: Double, focus: CGPoint? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.scale = scale
        self.focus = focus
    }
}

/// How close the frame is at a moment, and what it's centered on (0…1 of the source).
public struct ZoomState: Equatable, Sendable {
    public let scale: Double
    public let center: CGPoint

    public static let none = ZoomState(scale: 1, center: CGPoint(x: 0.5, y: 0.5))

    public init(scale: Double, center: CGPoint) {
        self.scale = scale
        self.center = center
    }

    /// The part of the source on screen, as a 0…1 rect with a top-left origin.
    public var viewport: CGRect {
        let side = 1 / scale
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }
}

public enum ZoomPlanner {
    /// How long the frame takes to move in or out of a zoom.
    public static let transition = 0.7

    /// Zooms where the person clicked: clicks close together in time share one zoom,
    /// which starts a little before the first and holds a little after the last.
    public static func automatic(clicks: [CursorTrack.Click], duration: Double, scale: Double = 2) -> [ZoomSegment] {
        let lead = 0.6, hold = 1.6, gap = 2.5, minimum = 1.5
        var segments: [ZoomSegment] = []
        for click in clicks.sorted(by: { $0.t < $1.t }) {
            if var last = segments.last, click.t - (last.end - hold) <= gap {
                last.end = min(duration, click.t + hold)
                segments[segments.count - 1] = last
            } else {
                segments.append(ZoomSegment(start: max(0, click.t - lead), end: min(duration, click.t + hold), scale: scale))
            }
        }
        // Too short to read as a zoom: stretched to the minimum, merged where they meet.
        var merged: [ZoomSegment] = []
        for var segment in segments {
            if segment.end - segment.start < minimum { segment.end = min(duration, segment.start + minimum) }
            if var last = merged.last, segment.start <= last.end + transition {
                last.end = max(last.end, segment.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(segment)
            }
        }
        return merged.filter { $0.end > $0.start }
    }

    /// The zoom at `t`: eased in over `transition` from each segment's start, eased out
    /// after its end, following `pointer` (already smoothed) unless the segment has a
    /// fixed focus. The view never slides past the recording's edges.
    public static func state(at t: Double, segments: [ZoomSegment], clamped: Bool = true, pointer: (Double) -> CGPoint?) -> ZoomState {
        var best: (weight: Double, segment: ZoomSegment)?
        for segment in segments {
            let weight: Double
            if t < segment.start || t > segment.end + transition {
                weight = 0
            } else if t < segment.start + transition {
                weight = (t - segment.start) / transition
            } else if t <= segment.end {
                weight = 1
            } else {
                weight = 1 - (t - segment.end) / transition
            }
            if weight > (best?.weight ?? 0) { best = (weight, segment) }
        }
        guard let (weight, segment) = best, weight > 0 else { return .none }
        let eased = ease(min(1, max(0, weight)))
        let scale = 1 + (segment.scale - 1) * eased
        let target = segment.focus ?? pointer(t) ?? CGPoint(x: 0.5, y: 0.5)
        let center = CGPoint(x: 0.5 + (target.x - 0.5) * eased, y: 0.5 + (target.y - 0.5) * eased)
        return ZoomState(scale: scale, center: clamped ? clamp(center, scale: scale) : center)
    }

    /// Keeps the viewport inside the recording.
    public static func clamp(_ center: CGPoint, scale: Double) -> CGPoint {
        let half = 0.5 / scale
        return CGPoint(x: min(1 - half, max(half, center.x)), y: min(1 - half, max(half, center.y)))
    }

    /// Smooth start and stop (cubic ease in-out).
    static func ease(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}
