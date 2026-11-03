import AppKit
import CleenKit
import SwiftUI

struct ClipboardCardContent: View {
    let entry: ClipboardEntry

    var body: some View {
        switch entry.kind {
        case .text:
            Text(entry.text ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.primary.opacity(0.9))
                .lineLimit(5)
        case .link:
            Text(entry.text ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.45, green: 0.68, blue: 1))
                .lineLimit(4)
        case .image:
            if let preview = entry.preview {
                ClipboardPreviewImage(entry: entry, preview: preview) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(NotchStyle.tertiary)
                }
            }
        case .files:
            VStack(alignment: .leading, spacing: 6) {
                if let first = entry.files?.first, let preview = entry.preview {
                    ClipboardPreviewImage(entry: entry, preview: preview) {
                        FileIcon(url: URL(filePath: first), size: 34)
                    }
                }
                Text(entry.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
}
