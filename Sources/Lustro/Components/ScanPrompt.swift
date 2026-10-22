import SwiftUI

/// What a section shows before its first scan: what it will look for, and one button.
struct ScanPrompt: View {
    let symbol: String
    let title: String
    let message: String
    var buttonTitle = "Analisar"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.surface, in: .circle)
                .overlay { Circle().strokeBorder(Theme.hairline) }
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(Theme.display(20))
                Text(message)
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Button(buttonTitle, action: action)
                .buttonStyle(.primaryLarge)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
