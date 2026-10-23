import SwiftUI

/// The Timer tab: countdowns and Pomodoro.
struct NotchTimerTab: View {

    var body: some View {
        Text("Timer")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
