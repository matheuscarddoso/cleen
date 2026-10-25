import CleenKit
import SwiftUI

struct AppPickerList: View {
    @Environment(AppsModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.visibleApps) { app in
                    AppPickerRow(app: app, isSelected: model.selectedID == app.id) {
                        model.selectedID = app.id
                        model.loadLeftovers()
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .scrollEdgeFade()
    }
}
