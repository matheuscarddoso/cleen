import SwiftUI

/// An SF Symbol on a soft circular plate, used as a row's leading icon.
struct SymbolBadge: View {
    let symbol: String
    var tint = NotchStyle.primary
    var size = 30.0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.1), in: .circle)
            .accessibilityHidden(true)
    }
}
