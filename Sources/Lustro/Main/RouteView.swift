import SwiftUI

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .overview: OverviewView()
        case .junk: JunkView()
        case .projects: ProjectsView()
        case .largeFiles: LargeFilesView()
        case .duplicates: DuplicatesView()
        case .spaceLens: SpaceLensView()
        case .uninstaller: UninstallerView()
        case .leftovers: OrphansView()
        case .startup: StartupView()
        case .monitor: MonitorView()
        case .maintenance: MaintenanceView()
        case .settings: SettingsView()
        }
    }
}
