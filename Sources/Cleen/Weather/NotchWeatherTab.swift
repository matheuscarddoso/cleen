import SwiftUI

/// The Tempo tab: now and the next seven days.
struct NotchWeatherTab: View {

    var body: some View {
        Text("Tempo")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
