import AppKit
import CleenKit
import SwiftUI

struct SpaceChildRow: View {
    @Environment(SpaceLensModel.self) private var model
    let node: SpaceNode
    let parentSize: Int64
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 9) {
            if node.isAggregate {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(NotchStyle.tertiary)
                    .frame(width: 18)
            } else {
                FileIcon(url: node.url, size: 18)
            }
            Text(node.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(node.isAggregate ? NotchStyle.secondary : NotchStyle.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 140, alignment: .leading)
            UsageBar(fraction: Double(node.size) / Double(max(parentSize, 1)), height: 3, tint: NotchStyle.barFill)
            Text(node.size.bytes)
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
                .frame(width: 62, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(NotchStyle.tertiary)
                .opacity(node.isNavigable ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(isHovered ? NotchStyle.control.opacity(0.5) : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .onTapGesture { model.open(node) }
        .contextMenu {
            if !node.isAggregate {
                Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([node.url]) }
                Button("Mover para o Lixo") { Task { await model.moveToTrash(node) } }
            }
        }
    }
}
