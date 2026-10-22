import LustroKit
import SwiftUI

struct UninstallerView: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            PageHeader(title: "Desinstalar apps", subtitle: subtitle) {
                TextField("Buscar", text: $model.search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Picker("Ordenar por", selection: $model.sort) {
                    ForEach(AppSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            if model.phase == .ready {
                HStack(spacing: 0) {
                    AppList()
                        .frame(width: 340)
                    Rectangle().fill(Theme.hairline).frame(width: 1)
                    AppDetail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
            } else {
                ScanningView(title: "Listando apps", detail: "Medindo cada app em /Applications")
            }
        }
        .task { if model.phase == .idle { await model.load() } }
    }

    private var subtitle: String {
        model.phase == .ready ? "\(model.apps.count) apps · \(model.totalSize.bytes)" : "Remove o app e tudo o que ele espalhou pelo Mac."
    }
}
