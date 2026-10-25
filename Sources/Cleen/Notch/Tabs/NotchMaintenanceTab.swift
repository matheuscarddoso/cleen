import CleenKit
import SwiftUI

/// Maintenance chores as two grouped lists side by side.
struct NotchMaintenanceTab: View {
    @Environment(MaintenanceModel.self) private var model

    var body: some View {
        let tasks = MaintenanceTask.allCases
        // Scrolls when the panel is shorter than the list (a smaller size in Aparência).
        NotchScroll {
            columns(tasks)
                .padding(.top, 4)
        }
        .task { await model.refresh() }
    }

    private func columns(_ tasks: [MaintenanceTask]) -> some View {
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
    }
}
