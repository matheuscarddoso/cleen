import CleenKit
import SwiftUI

struct AppPickerRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 9) {
                FileIcon(url: app.url, size: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(usage)
                        .font(.system(size: 9.5))
                        .foregroundStyle(NotchStyle.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(app.size.bytes)
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(NotchStyle.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(isSelected ? NotchStyle.selection : (isHovered ? NotchStyle.control.opacity(0.5) : .clear), in: .rect(cornerRadius: 8, style: .continuous))
            .opacity(app.isSystem ? 0.5 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var usage: String {
        if app.isSystem { return String(localized: "Faz parte do macOS") }
        guard let lastUsed = app.lastUsed else { return String(localized: "Sem registro de uso") }
        return String(localized: "Aberto \(lastUsed.relative)")
    }
}
