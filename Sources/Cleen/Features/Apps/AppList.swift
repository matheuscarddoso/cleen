import CleenKit
import SwiftUI

struct AppList: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selectedID) {
            ForEach(model.visibleApps) { app in
                AppListRow(app: app)
                    .tag(app.id)
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .alternatingRowBackgrounds(.disabled)
        .onChange(of: model.selectedID) {
            model.loadLeftovers()
        }
    }
}
