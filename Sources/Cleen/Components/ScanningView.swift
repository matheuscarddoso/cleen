import SwiftUI

/// In-progress state: what's happening, where, and a way out.
struct ScanningView: View {
    let title: String
    let detail: String
    var cancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .tint(Theme.accent)
            VStack(spacing: 6) {
                Text(title)
                    .font(Theme.display(20))
                Text(detail.isEmpty ? " " : detail)
                    .font(.system(size: 11.5).monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 460)
                    .contentTransition(.opacity)
            }
            if let cancel {
                Button("Parar", action: cancel)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}
