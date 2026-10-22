import SwiftUI

struct Sidebar: View {
    @Binding var route: Route
    @Environment(CleanupService.self) private var cleanup

    var body: some View {
        List(selection: $route) {
            ForEach(Route.Group.allCases, id: \.self) { group in
                Section {
                    ForEach(group.routes) { route in
                        Label(route.title, systemImage: route.symbol)
                            .tag(route)
                    }
                } header: {
                    if !group.rawValue.isEmpty {
                        Text(group.rawValue)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if cleanup.lifetimeFreed > 0 {
                LifetimeFooter(bytes: cleanup.lifetimeFreed)
            }
        }
    }
}
