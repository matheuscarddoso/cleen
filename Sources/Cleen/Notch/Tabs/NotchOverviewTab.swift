import SwiftUI

/// The Mac at a glance: the disk with its one-click cleanup, what the scan found, and
/// live vitals that each lead to their tool.
struct NotchOverviewTab: View {
    let controller: NotchController

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                NotchDiskCard(controller: controller)
                NotchFindingsRow(controller: controller)
            }
            .frame(width: 400)
            NotchVitalsColumn()
        }
    }
}
