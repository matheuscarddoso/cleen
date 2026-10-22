import SwiftUI

/// Three segments in one capsule: used (white), reclaimable (accent), free (track).
struct DiskUsageShape: View {
    let used: Double
    let reclaimable: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.track)
            LeadingCapsule(fraction: used + reclaimable).fill(Theme.accent)
            LeadingCapsule(fraction: used).fill(.white.opacity(0.75))
        }
        .clipShape(.capsule)
    }
}
