import SwiftUI

/// The Lembretes tab: Apple Reminders, with a field to add one.
struct NotchRemindersTab: View {

    var body: some View {
        Text("Lembretes")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
