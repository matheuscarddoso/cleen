import AppKit
import LustroKit
import SwiftUI

/// A file with its icon, where it lives, when it was last used and its size.
struct FileRow: View {
    let file: FoundFile
    let isSelected: Bool
    var maxSize: Int64 = 0
    var badge: String?
    let toggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Checkbox(state: isSelected ? .on : .off, label: file.name, action: toggle)
            FileIcon(url: file.url, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(file.name)
                        .font(Theme.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let badge {
                        Text(badge)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.good)
                    }
                }
                Text("\(Paths.abbreviate(file.url.deletingLastPathComponent())) · usado \(file.lastUsed.relative)")
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            if isHovered {
                Button("Abrir", systemImage: "eye", action: preview)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Abrir")
                RevealButton(url: file.url)
            }
            VStack(alignment: .trailing, spacing: 4) {
                Text(file.size.bytes)
                    .font(Theme.body)
                    .monospacedDigit()
                if maxSize > 0 {
                    ProportionBar(fraction: Double(file.size) / Double(maxSize))
                        .frame(width: 72)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Theme.surfaceHover : .clear, in: .rect(cornerRadius: Theme.Radius.medium))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: preview)
        .help(file.url.path(percentEncoded: false))
    }

    private func preview() {
        NSWorkspace.shared.open(file.url)
    }
}
