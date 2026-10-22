import CleenKit
import SwiftUI

struct FailuresSheet: View {
    let failures: [RemovalFailure]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Não removidos")
                .font(Theme.display(22))
                .padding(24)
            List(failures) { failure in
                VStack(alignment: .leading, spacing: 3) {
                    Text(Paths.abbreviate(failure.url))
                        .font(.system(size: 12).monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(failure.reason)
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
            .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("OK", action: close)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 520, height: 380)
        .background(Theme.canvas)
    }

    private func close() {
        dismiss()
    }
}
