import CleenKit
import SwiftUI

struct LargeFilesList: View {
    @Environment(LargeFilesModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let files = model.visibleFiles
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let report = model.report {
                    ReportBanner(report: report)
                }
                HStack(spacing: 10) {
                    KindFilter(selection: $model.kind, kinds: model.kindsPresent)
                    Spacer()
                    Picker("Ordem", selection: $model.sort) {
                        ForEach(FileSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in
                        FileRow(
                            file: file,
                            isSelected: model.selection.contains(file.url),
                            maxSize: model.files.first?.size ?? 1,
                            toggle: { model.toggle(file) }
                        )
                    }
                }
                .surface(padding: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .animation(Theme.standard, value: model.report)
        }
    }
}
