import SwiftUI

struct NotchScanning: View {
    let title: String
    let detail: String
    var cancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            VStack(spacing: 3) {
                Text(title)
                    .font(NotchStyle.headline)
                Text(detail.isEmpty ? " " : detail)
                    .font(.system(size: 10.5).monospaced())
                    .foregroundStyle(NotchStyle.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420)
            }
            if let cancel {
                Button("Parar", action: cancel)
                    .buttonStyle(.notchSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
