import SwiftUI

/// The open panel: header in the notch strip, the selected tool, and the tab bar.
struct NotchOpenContent: View {
    let controller: NotchController
    let notchHeight: Double
    @Environment(NotchState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(controller: controller)
                .frame(height: notchHeight)
                .padding(.horizontal, 10)
            Group {
                switch state.tab {
                case .home: NotchHomeTab()
                case .overview: NotchOverviewTab(controller: controller)
                case .clean: NotchCleanTab()
                case .projects: NotchProjectsTab()
                case .files: NotchFilesTab()
                case .system: NotchSystemTab()
                case .startup: NotchStartupTab()
                case .maintenance: NotchMaintenanceTab()
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .padding(.top, 6)
            NotchTabBar(controller: controller)
                .padding(.bottom, 10)
                .padding(.top, 6)
        }
        .foregroundStyle(NotchStyle.primary)
    }
}
