import SwiftUI

/// Watched tickers on Início.
struct StocksWidget: View {
    let size: HomeWidgetSize

    var body: some View {
        Text("Ações")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
