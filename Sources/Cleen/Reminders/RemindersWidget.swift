import SwiftUI

/// Open reminders on Início.
struct RemindersWidget: View {
    let size: HomeWidgetSize

    var body: some View {
        Text("Lembretes")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
