import SwiftUI

/// The Perguntar tab: Apple Intelligence, on this Mac.
struct NotchAssistantTab: View {

    var body: some View {
        Text("Perguntar")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
