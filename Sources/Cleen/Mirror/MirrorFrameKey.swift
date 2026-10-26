import SwiftUI

/// Where the round mirror sits on Início, so the one live preview can be laid over it
/// and grow from exactly there.
struct MirrorFrameKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
