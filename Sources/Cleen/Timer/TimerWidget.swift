import SwiftUI

/// The timer on Início.
struct TimerWidget: View {
    let size: HomeWidgetSize

    var body: some View {
        Text("Timer")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
