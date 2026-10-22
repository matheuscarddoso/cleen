import SwiftUI

@main
struct CleenApp: App {
    @State private var app = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu()
                .injecting(app)
        } label: {
            MenuBarLabel()
                .injecting(app)
        }
        .menuBarExtraStyle(.menu)

        Window("Cleen", id: MainWindow.id) {
            MainWindow()
                .injecting(app)
        }
        // No title bar or toolbar at all: an empty, invisible toolbar made macOS drop its
        // reserved height now and then, shifting the whole window up under the
        // traffic lights. The layout keeps its own top inset instead.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(LaunchArguments.route == nil ? .suppressed : .presented)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
