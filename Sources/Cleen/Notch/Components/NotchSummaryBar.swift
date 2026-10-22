import SwiftUI

/// Top row of a list tool: the selected total as the headline, a caption, actions.
struct NotchSummaryBar<Actions: View>: View {
    let value: String
    let caption: String
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
                Text(caption)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            actions
        }
        .animation(.smooth(duration: 0.2), value: value)
    }
}
