import CleenKit
import SwiftUI

/// Maintenance chores as two grouped lists side by side.
struct NotchMaintenanceTab: View {
    @Environment(MaintenanceModel.self) private var model

    var body: some View {
        let tasks = MaintenanceTask.allCases
        HStack(alignment: .top, spacing: 10) {
            NotchGroup {
                ForEach(tasks.prefix(4)) { task in
                    NotchMaintenanceRow(task: task)
                }
            }
            NotchGroup {
                ForEach(tasks.dropFirst(4)) { task in
                    NotchMaintenanceRow(task: task)
                }
            }
        }
        .padding(.top, 4)
        .task { await model.refresh() }
    }
}
