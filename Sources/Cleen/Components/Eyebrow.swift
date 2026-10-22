import SwiftUI

/// Small uppercase label above a group of rows.
struct Eyebrow: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased())
                .tracking(0.8)
            Spacer()
            if let trailing {
                Text(trailing)
                    .monospacedDigit()
            }
        }
        .font(Theme.eyebrow)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}
