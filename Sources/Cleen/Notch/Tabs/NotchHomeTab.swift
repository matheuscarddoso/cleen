import SwiftUI

/// The notch's front page: a greeting, the disk with its one-click cleanup, and a
/// column of live vitals that each lead to their tool.
struct NotchHomeTab: View {
    let controller: NotchController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotchGreeting()
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 8) {
                    NotchDiskCard(controller: controller)
                    NotchFindingsRow(controller: controller)
                }
                .frame(width: 390)
                NotchVitalsColumn()
            }
        }
    }
}
