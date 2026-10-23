import SwiftUI

/// The weather on Início.
struct WeatherWidget: View {
    let size: HomeWidgetSize

    var body: some View {
        Text("Tempo")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
