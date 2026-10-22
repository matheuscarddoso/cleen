import SwiftUI

/// The happy empty state after a scan finds nothing.
struct AllClearView: View {
    let title: String
    let message: String
    let rescan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.display(20))
            Text(message)
                .font(Theme.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Analisar de novo", action: rescan)
                .buttonStyle(.quiet)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
