import LustroKit
import SwiftUI

struct JunkItemRow: View {
    @Environment(JunkModel.self) private var model
    let item: JunkItem
    let maxSize: Int64
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Checkbox(state: model.selection.contains(item.url) ? .on : .off, label: item.name, action: toggle)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(Theme.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let note = item.note {
                        Text(note)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.warning)
                    }
                }
                ProportionBar(fraction: Double(item.size) / Double(max(maxSize, 1)), tint: Theme.accent.opacity(0.7))
                    .frame(maxWidth: 160)
            }
            Spacer(minLength: 12)
            RevealButton(url: item.url)
                .opacity(isHovered ? 1 : 0)
            Text(item.size.bytes)
                .font(Theme.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.leading, 47)
        .padding(.trailing, 40)
        .padding(.vertical, 7)
        .background(isHovered ? Theme.surfaceHover : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .help(Paths.abbreviate(item.url))
    }

    private func toggle() {
        model.toggle(item)
    }
}
