import SwiftUI

/// A dense list row with hover highlight: leading content, title, subtitle, trailing value.
struct NotchRow<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    var subtitleColor: Color = NotchStyle.tertiary
    var verticalPadding = 6.0
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(NotchStyle.bodyMedium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle {
                    Text(subtitle)
                        .font(NotchStyle.caption)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 8)
        .padding(.vertical, verticalPadding)
        .background(isHovered ? NotchStyle.control.opacity(0.6) : .clear, in: .rect(cornerRadius: 9, style: .continuous))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
    }
}
