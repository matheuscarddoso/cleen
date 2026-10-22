import SwiftUI

struct PromiseRow: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(Theme.body)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}
