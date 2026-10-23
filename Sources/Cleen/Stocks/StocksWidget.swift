import CleenKit
import SwiftUI

/// The first tickers of the watchlist on Início: two at medium (ticker, price, change),
/// three at large with today's line next to each. A tap opens Ações.
struct StocksWidget: View {
    let size: HomeWidgetSize
    @Environment(StocksModel.self) private var model
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .stocks } label: {
            VStack(alignment: .leading, spacing: size == .large ? 5 : 8) {
                HomeWidgetLabel(title: String(localized: "Ações"), symbol: "chart.line.uptrend.xyaxis")
                if !model.isRestored {
                    Color.clear.frame(height: 1)
                } else if shown.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(shown) { quote in
                        row(quote)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Abrir Ações")
        .task { await model.watch() }
    }

    private var shown: [StockQuote] {
        Array(model.listedQuotes.prefix(size == .large ? 3 : 2))
    }

    private var placeholder: String {
        if model.symbols.isEmpty { return String(localized: "Adicione ações na aba Ações.") }
        return model.lastRefreshFailed ? String(localized: "Sem conexão") : String(localized: "Buscando…")
    }

    private func row(_ quote: StockQuote) -> some View {
        HStack(spacing: 6) {
            Text(quote.displaySymbol)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            if size == .large {
                StockSparkline(quote: quote, lineWidth: 1, showsBaseline: false)
                    .frame(width: 44, height: 14)
            }
            Text(StockFormat.price(quote))
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(NotchStyle.primary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
            StockChangePill(quote: quote, fontSize: 10)
        }
        .animation(.smooth(duration: 0.3), value: quote.price)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(quote.displaySymbol), \(StockFormat.price(quote)), \(quote.changeFraction.map { StockFormat.change($0) } ?? "")")
    }
}
