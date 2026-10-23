import AppKit
import CleenKit
import SwiftUI

struct ClipboardCardContent: View {
    @Environment(ClipboardModel.self) private var model
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
            if let url = model.imageURL(for: entry) {
                ThumbnailImage(url: url, mode: .fill)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
            }
        case .files:
            VStack(alignment: .leading, spacing: 4) {
                if let first = entry.files?.first {
                    FileIcon(url: URL(filePath: first), size: 34)
                }
                Text(entry.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
}
