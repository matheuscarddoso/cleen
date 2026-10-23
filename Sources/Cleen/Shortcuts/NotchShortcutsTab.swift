import SwiftUI

/// The Atalhos tab: run the person's macOS Shortcuts.
struct NotchShortcutsTab: View {

    var body: some View {
        Text("Atalhos")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
