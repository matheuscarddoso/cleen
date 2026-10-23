import SwiftUI

extension View {
    /// Puts the app model and every feature model into the environment.
    func injecting(_ app: AppModel) -> some View {
        environment(app)
            .environment(app.cleanup)
            .environment(app.monitor)
            .environment(app.junk)
            .environment(app.projects)
            .environment(app.largeFiles)
            .environment(app.duplicates)
            .environment(app.spaceLens)
            .environment(app.apps)
            .environment(app.orphans)
            .environment(app.startup)
            .environment(app.maintenance)
            .environment(app.nowPlaying)
            .environment(app.agenda)
            .environment(app.aiUsage)
            .environment(app.shelf)
            .environment(app.tabs)
            .environment(app.mirror)
            .environment(app.clipboard)
    }
}
