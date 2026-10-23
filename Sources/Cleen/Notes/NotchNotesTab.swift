import SwiftUI

/// The Notas tab: a quick note that saves itself.
struct NotchNotesTab: View {

    var body: some View {
        Text("Notas")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
