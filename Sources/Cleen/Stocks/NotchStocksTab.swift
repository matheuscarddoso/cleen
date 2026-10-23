import SwiftUI

/// The Ações tab: tickers with today's chart.
struct NotchStocksTab: View {

    var body: some View {
        Text("Ações")
            .font(NotchStyle.body)
            .foregroundStyle(NotchStyle.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
