import AppKit
import SwiftUI

/// One result: icon, title (and subtitle), and the kind on the right.
struct SearchRow: View {
    let item: SearchItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 20, height: 20)
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NotchStyle.primary)
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(NotchStyle.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let kind = item.kind {
                Text(kind)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? NotchStyle.secondary : NotchStyle.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(isSelected ? NotchStyle.selection : .clear, in: .rect(cornerRadius: 8, style: .continuous))
        .contentShape(.rect)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.icon {
        case .symbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color.gradient, in: .rect(cornerRadius: 5.5, style: .continuous))
        case .app(let url):
            FileIcon(url: url, size: 20)
        case .emoji(let emoji):
            Text(emoji).font(.system(size: 16))
        case .color(let color):
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: color))
                .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.2)) }
        case .lucide(let icon):
            LucideGlyph(icon: icon, size: 14)
                .foregroundStyle(NotchStyle.primary)
                .frame(width: 20, height: 20)
                .background(NotchStyle.control, in: .rect(cornerRadius: 6, style: .continuous))
        case .text(let text):
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchStyle.secondary)
        }
    }
}
