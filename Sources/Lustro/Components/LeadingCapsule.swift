import SwiftUI

/// A capsule filling the leading `fraction` of its frame (never thinner than its height,
/// so a tiny share still reads as a dot rather than vanishing).
@Animatable
struct LeadingCapsule: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let width = max(rect.height, rect.width * min(1, max(0, fraction)))
        return Capsule().path(in: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
    }
}
