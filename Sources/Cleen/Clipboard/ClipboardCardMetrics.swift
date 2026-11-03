import Foundation

extension ClipboardCard {
    /// The card's frame, shared by everything drawn inside it so the shapes stay concentric.
    enum Metrics {
        static let width = 128.0
        static let height = 112.0
        static let padding = 10.0
        static let radius = 12.0
        /// Corners of whatever fills the content area: the card's, less the padding.
        static let innerRadius = max(radius - padding, 0)
    }
}
