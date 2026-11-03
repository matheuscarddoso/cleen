import SwiftUI

/// One slot in the dock: a tool, the button that expands or folds the dock, or the hairline
/// between the dock's groups.
nonisolated enum NotchDockItem: Hashable, Identifiable {
    case tab(NotchTab)
    case toggle
    case divider(Int)

    var id: Self { self }

    var width: Double {
        if case .divider = self { return NotchDockLayout.dividerWidth }
        return NotchDockLayout.buttonWidth
    }
}

/// The dock's measurements. It is always one row: expanded past the panel's width, it
/// scrolls sideways rather than wrapping.
///
/// The radii are concentric: the dock's ends are a capsule's (`height / 2`), and the row
/// inside sits `padding` in from them, so its own corners (the buttons' pills, and the
/// clip the row scrolls under) are `cornerRadius - padding`.
nonisolated enum NotchDockLayout {
    /// A tool's button, as wide as `NotchTabButton` draws it.
    static let buttonWidth = 32.0
    static let padding = 4.0
    static let spacing = 1.0
    static let rowHeight = 30.0
    static let dividerWidth = 9.0
    /// How far the row fades out at an edge with more to scroll to.
    static let fade = 18.0

    static var height: Double { padding * 2 + rowHeight }
    static var cornerRadius: Double { height / 2 }
    static var innerRadius: Double { cornerRadius - padding }

    /// The row's natural width: every item side by side.
    static func contentWidth(_ items: [NotchDockItem]) -> Double {
        items.map(\.width).reduce(0, +) + spacing * Double(max(0, items.count - 1))
    }
}
