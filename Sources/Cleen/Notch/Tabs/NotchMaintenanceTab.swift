import CleenKit
import SwiftUI

struct NotchMaintenanceTab: View {
    @Environment(MaintenanceModel.self) private var model

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(MaintenanceTask.allCases) { task in
                NotchMaintenanceTile(task: task)
            }
        }
        .task { await model.refresh() }
    }
}
