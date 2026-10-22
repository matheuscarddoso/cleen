import LustroKit
import SwiftUI

struct DuplicatesList: View {
    @Environment(DuplicatesModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let report = model.report {
                    ReportBanner(report: report)
                }
                ForEach(model.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(
                            text: "\(group.files.count) cópias de \(group.fileSize.bytes)",
                            trailing: model.removesEveryCopy(of: group) ? "nenhuma cópia fica" : nil
                        )
                        VStack(spacing: 0) {
                            ForEach(group.files) { file in
                                FileRow(
                                    file: file,
                                    isSelected: model.selection.contains(file.url),
                                    badge: model.selection.contains(file.url) ? nil : "fica",
                                    toggle: { model.toggle(file) }
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
}
