import SwiftUI

@main
struct LustroApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .injecting(app)
        } label: {
            MenuBarLabel()
                .environment(app.monitor)
        }
        .menuBarExtraStyle(.window)

        Window("Lustro", id: MainWindow.id) {
            MainWindow()
                .injecting(app)
        }
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(LaunchArguments.route == nil ? .suppressed : .presented)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // The menu bar panel in an ordinary window, for screenshots (`--panel-preview`).
        Window("Prévia do painel", id: "panel-preview") {
            MenuBarPanel()
                .injecting(app)
                .background(.regularMaterial)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(LaunchArguments.panelPreview ? .presented : .suppressed)
    }
}
