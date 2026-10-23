import SwiftUI

struct CardButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(NotchStyle.primary.opacity(0.8))
                .frame(width: 16, height: 16)
                .background(NotchStyle.control, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
