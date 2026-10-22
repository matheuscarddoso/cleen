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
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(LaunchArguments.route == nil ? .suppressed : .presented)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
