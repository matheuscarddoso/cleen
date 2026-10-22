import LustroKit
import SwiftUI

struct ArtifactRow: View {
    @Environment(ProjectsModel.self) private var model
    let artifact: ProjectArtifact
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Checkbox(state: model.selection.contains(artifact.url) ? .on : .off, label: artifact.kind.title, action: toggle)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.kind.title)
                    .font(Theme.body)
                Text("\(relativePath) · volta com \(artifact.kind.restoreHint)")
                    .font(Theme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            RevealButton(url: artifact.url)
                .opacity(isHovered ? 1 : 0)
            Text(artifact.size.bytes)
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
    }

    private var relativePath: String { artifact.url.lastPathComponent }

    private func toggle() {
        model.toggle(artifact)
    }
}
