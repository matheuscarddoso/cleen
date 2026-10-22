import LustroKit
import SwiftUI

struct ProjectsList: View {
    @Environment(ProjectsModel.self) private var model
    @State private var expanded = Set<URL>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let report = model.report {
                    ReportBanner(report: report)
                }
                HStack(spacing: 8) {
                    Eyebrow(text: "\(model.projects.count) projetos")
                    Spacer()
                    Button("Marcar parados", action: model.selectStale)
                        .buttonStyle(.quiet)
                    Button("Desmarcar tudo", action: model.selectNone)
                        .buttonStyle(.quiet)
                }
                LazyVStack(spacing: 0) {
                    ForEach(model.projects) { project in
                        ProjectRow(
                            project: project,
                            maxSize: model.projects.first?.totalSize ?? 1,
                            isExpanded: expanded.contains(project.id),
                            toggleExpansion: { toggle(project.id) }
                        )
                        if project.id != model.projects.last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 48)
                        }
                    }
                }
                .surface(padding: 0)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .animation(Theme.standard, value: model.report)
        }
    }

    private func toggle(_ id: URL) {
        withAnimation(Theme.standard) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }
}
