import SwiftUI

/// A quiet running total at the foot of the sidebar.
struct LifetimeFooter: View {
    let bytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bytes.bytes)
                .font(Theme.display(17))
                .monospacedDigit()
            Text("liberados pelo Cleen")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
