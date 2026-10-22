import SwiftUI

/// Sticky footer for any list with a selection: what's selected, what happens to it,
/// and the button that does it.
struct CleanupBar: View {
    let selectedCount: Int
    let selectedSize: Int64
    let actionTitle: String
    /// Where the files go, so nobody is surprised: "Apagados de vez" or "Vão para o Lixo".
    let destination: String
    var isWorking = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSize.bytes)
                    .font(Theme.display(22))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(selectedCount == 1 ? "1 item selecionado · \(destination)" : "\(selectedCount) itens selecionados · \(destination)")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
            }
            .animation(Theme.quick, value: selectedSize)
            Spacer()
            if isWorking {
                ProgressView().controlSize(.small)
            }
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedCount == 0 || isWorking)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}
