import AppKit
import SwiftUI

struct MainWindow: View {
    static let id = "main"

    @Environment(AppModel.self) private var app
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var app = app
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar(route: $app.route)
                .frame(minHeight: 0, maxHeight: .infinity)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            // minHeight 0: a page never sets the window's minimum height. Without it the
            // window took the tallest page's ideal height (up to 1168 pt in a 760 pt
            // window) and the split view overflowed, sliding up under the traffic lights.
            RouteView(route: app.route)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .background(Theme.canvas)
        }
        .frame(minWidth: 920, minHeight: 620)
        .toolbar(removing: .sidebarToggle)
        // Lists and pages scroll only when their content doesn't fit; a short list
        // can't be dragged up under the traffic lights.
        .scrollBounceBehavior(.basedOnSize)
        .onAppear(perform: becomeRegularApp)
        .onDisappear(perform: returnToMenuBar)
    }

    /// While the window is open Cleen behaves like a normal app (Dock icon, ⌘-Tab).
    private func becomeRegularApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        if ProcessInfo.processInfo.arguments.contains("--dump-views") {
            Task {
                try? await Task.sleep(for: .seconds(6))
                for window in NSApp.windows where window.title == "Cleen" {
                    if let view = window.contentView?.superview { ViewHierarchyDump.dump(view) }
                }
            }
        }
    }

    /// Back to living only in the menu bar.
    private func returnToMenuBar() {
        NSApp.setActivationPolicy(.accessory)
    }
}
