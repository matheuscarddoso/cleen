import SwiftUI

/// The small grey heading a widget opens with: "Disco", "Sistema".
struct HomeWidgetLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NotchStyle.secondary)
            .lineLimit(1)
    }
}
