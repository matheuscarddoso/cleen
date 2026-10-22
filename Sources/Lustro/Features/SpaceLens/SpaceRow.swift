import AppKit
import LustroKit
import SwiftUI

struct SpaceRow: View {
    @Environment(SpaceLensModel.self) private var model
    let node: SpaceNode
    let parentSize: Int64
    let isHighlighted: Bool
    @State private var confirming = false

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if node.isAggregate {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.tertiary)
                        .frame(width: 26, height: 26)
                } else {
                    FileIcon(url: node.url, size: 26)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(Theme.body)
                    .foregroundStyle(node.isAggregate ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProportionBar(fraction: Double(node.size) / Double(max(parentSize, 1)))
            }
            Text(node.size.bytes)
                .font(Theme.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .opacity(node.isNavigable ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHighlighted ? Theme.surfaceHover : .clear, in: .rect(cornerRadius: Theme.Radius.medium))
        .contentShape(.rect)
        .onTapGesture(perform: open)
        .contextMenu {
            if !node.isAggregate {
                Button("Mostrar no Finder", action: reveal)
                Button("Mover para o Lixo…", action: confirm)
            }
        }
        .confirmationDialog("Mover \(node.name) para o Lixo?", isPresented: $confirming) {
            Button("Mover para o Lixo (\(node.size.bytes))", role: .destructive, action: trash)
        } message: {
            Text("Fica recuperável no Lixo até você esvaziá-lo.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(node.isNavigable ? .isButton : [])
    }

    private func open() {
        model.open(node)
    }

    private func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    private func confirm() {
        confirming = true
    }

    private func trash() {
        Task { await model.moveToTrash(node) }
    }
}
