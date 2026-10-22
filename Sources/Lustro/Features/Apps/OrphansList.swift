import LustroKit
import SwiftUI

struct OrphansList: View {
    @Environment(OrphansModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let report = model.report {
                    ReportBanner(report: report)
                }
                ForEach(model.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Checkbox(state: model.state(of: group), label: group.displayName) { model.toggle(group) }
                            Text(group.displayName)
                                .font(Theme.bodyMedium)
                            Text(group.bundleID)
                                .font(Theme.caption)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(group.totalSize.bytes)
                                .font(Theme.body)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        VStack(spacing: 0) {
                            ForEach(group.items) { item in
                                LeftoverRow(
                                    leftover: item,
                                    isSelected: model.selection.contains(item.url),
                                    toggle: { toggle(item) }
                                )
                            }
                        }
                        .surface(padding: 4)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .animation(Theme.standard, value: model.report)
        }
    }

    private func toggle(_ item: Leftover) {
        if model.selection.contains(item.url) { model.selection.remove(item.url) } else { model.selection.insert(item.url) }
    }
}
