import SwiftUI

/// What a notch tool shows before it has anything: one line on what it does, one button.
struct NotchPrompt: View {
    let symbol: String
    let color: Color
    let title: String
    let message: String
    var buttonTitle = String(localized: "Analisar")
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ToolIcon(symbol: symbol, color: color, size: 34)
            VStack(spacing: 3) {
                Text(title)
                    .font(NotchStyle.headline)
                Text(message)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Button(buttonTitle, action: action)
                .buttonStyle(.notchPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
