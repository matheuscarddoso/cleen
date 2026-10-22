import SwiftUI

/// Cleen lives in the notch; the menu bar item is a way in and out of it.
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
    }
}
