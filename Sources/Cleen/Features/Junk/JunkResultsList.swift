import CleenKit
import SwiftUI

struct JunkResultsList: View {
    @Environment(JunkModel.self) private var model
    let hasFullDiskAccess: Bool
    @State private var expanded = Set<String>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !hasFullDiskAccess {
                    FullDiskAccessBanner()
                }
                if let report = model.report {
                    ReportBanner(report: report)
                }
                ForEach(JunkCategory.Group.allCases, id: \.self) { group in
                    let results = model.results.filter { $0.category.group == group }
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: group.rawValue, trailing: results.reduce(0) { $0 + $1.totalSize }.bytes)
                            VStack(spacing: 0) {
                                ForEach(results) { result in
                                    JunkCategoryRow(
                                        result: result,
                                        isExpanded: expanded.contains(result.id),
                                        toggleExpansion: { toggleExpansion(result.id) }
                                    )
                                    if result.id != results.last?.id {
                                        Divider().overlay(Theme.hairline).padding(.leading, 64)
                                    }
                                }
                            }
                            .surface(padding: 0)
                        }
                    }
                }
                if !model.tools.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Ferramentas", trailing: model.tools.reduce(0) { $0 + $1.reclaimable }.bytes)
                        VStack(spacing: 0) {
                            ForEach(model.tools) { tool in
                                ToolCleanupRow(tool: tool)
                            }
                        }
                        .surface(padding: 0)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .animation(Theme.standard, value: model.report)
        }
    }

    private func toggleExpansion(_ id: String) {
        withAnimation(Theme.standard) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }
}
