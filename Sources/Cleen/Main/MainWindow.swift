import AppKit
import SwiftUI

struct MainWindow: View {
    static let id = "main"

    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            Sidebar(route: $app.route)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            RouteView(route: app.route)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.canvas)
        }
        .frame(minWidth: 920, minHeight: 620)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear(perform: becomeRegularApp)
        .onDisappear(perform: returnToMenuBar)
    }

    /// While the window is open Cleen behaves like a normal app (Dock icon, ⌘-Tab).
    private func becomeRegularApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Back to living only in the menu bar.
    private func returnToMenuBar() {
        NSApp.setActivationPolicy(.accessory)
    }
}
