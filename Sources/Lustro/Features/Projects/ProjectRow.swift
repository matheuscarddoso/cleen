import LustroKit
import SwiftUI

struct ProjectRow: View {
    @Environment(ProjectsModel.self) private var model
    let project: CodeProject
    let maxSize: Int64
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Checkbox(state: model.state(of: project), label: project.name, action: toggleProject)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(Theme.bodyMedium)
                        if isStale {
                            Text("parado")
                                .font(Theme.caption)
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Theme.accent.opacity(0.12), in: .capsule)
                        }
                    }
                    Text("\(Paths.abbreviate(project.url)) · mexido \(project.lastActivity.relative)")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    ProportionBar(fraction: Double(project.totalSize) / Double(max(maxSize, 1)))
                        .frame(maxWidth: 220)
                }
                Spacer(minLength: 16)
                Text(project.totalSize.bytes)
                    .font(Theme.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
            .onTapGesture(perform: toggleExpansion)
            .accessibilityAction(named: isExpanded ? "Recolher" : "Expandir", toggleExpansion)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(project.artifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private var isStale: Bool { project.isStale(threshold: model.staleThreshold) }

    private func toggleProject() {
        model.toggle(project)
    }
}
