import LustroKit
import SwiftUI

struct LeftoverRow: View {
    let leftover: Leftover
    let isSelected: Bool
    let toggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Checkbox(state: isSelected ? .on : .off, label: leftover.url.lastPathComponent, action: toggle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(leftover.place.rawValue)
                        .font(Theme.body)
                    if leftover.place.holdsUserData {
                        Text("pode ter dados seus")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.warning)
                    }
                    if leftover.place.isSystemWide {
                        Image(systemName: "lock")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .help("Pede a senha de administrador")
                    }
                }
                Text(Paths.abbreviate(leftover.url))
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            RevealButton(url: leftover.url)
                .opacity(isHovered ? 1 : 0)
            Text(leftover.size.bytes)
                .font(Theme.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Theme.surfaceHover : .clear, in: .rect(cornerRadius: Theme.Radius.medium))
        .contentShape(.rect)
        .onHover { isHovered = $0 }
    }
}
