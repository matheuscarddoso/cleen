import SwiftUI

/// What a section shows before its first scan: what it will look for, and one button.
struct ScanPrompt: View {
    let symbol: String
    var color = Theme.accent
    let title: String
    let message: String
    var buttonTitle = "Analisar"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ToolIcon(symbol: symbol, color: color, size: 60)
            VStack(spacing: 6) {
                Text(title)
                    .font(Theme.display(19))
                Text(message)
                    .font(Theme.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
