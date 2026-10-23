import CleenKit
import SwiftUI

/// One ticker on the Ações list: ticker and company on the left, today's line in the
/// middle, price and the day's change on the right. Hovering shows a − to take it off
/// the list; dragging it onto another card moves it there.
struct StockRow: View {
    let symbol: String
    let quote: StockQuote?
    let isUnknown: Bool
    /// Mark this ticker's market as closed (only when the others are open; when every
    /// market is closed the header says so once).
    var showsClosed = false
    @Environment(StocksModel.self) private var model
    @State private var isHovered = false
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            names
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let quote {
                    StockSparkline(quote: quote)
                }
            }
            .frame(width: 60, height: 24)
            figures
            removeButton
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(isHovered ? NotchStyle.control.opacity(0.6) : NotchStyle.card, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isTargeted ? NotchStyle.primary.opacity(0.35) : NotchStyle.cardStroke)
        }
        .contentShape(.rect(cornerRadius: 10))
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.12), value: isHovered)
        .animation(.smooth(duration: 0.12), value: isTargeted)
        .draggable(symbol) {
            Text(StockSymbol.display(symbol))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black, in: .capsule)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let dragged = items.first, model.symbols.contains(dragged) else { return false }
            withAnimation(.smooth(duration: 0.25)) { model.move(dragged, to: symbol) }
            return true
        } isTargeted: { isTargeted = $0 }
        .help(tooltip)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: Text("Remover da lista")) { model.remove(symbol) }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(StockSymbol.display(symbol))
                    .font(.system(size: 13, weight: .semibold))
                if showsClosed {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(NotchStyle.tertiary)
                        .help("Mercado fechado")
                }
            }
            Text(subtitle)
                .font(NotchStyle.caption)
                .foregroundStyle(isUnknown ? NotchStyle.warning : NotchStyle.secondary)
                .truncationMode(.tail)
        }
        .lineLimit(1)
    }

    private var subtitle: String {
        if let quote { return quote.name }
        if isUnknown { return String(localized: "Código não encontrado") }
        return model.lastRefreshFailed ? String(localized: "Sem conexão") : String(localized: "Carregando…")
    }

    private var figures: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(quote.map { StockFormat.price($0) } ?? "—")
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(quote == nil ? NotchStyle.tertiary : NotchStyle.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
            if let quote {
                StockChangePill(quote: quote)
            }
        }
        .animation(.smooth(duration: 0.3), value: quote?.price)
        .fixedSize()
    }

    private var removeButton: some View {
        Button { withAnimation(.smooth(duration: 0.25)) { model.remove(symbol) } } label: {
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(NotchStyle.primary)
                .frame(width: 18, height: 18)
                .background(NotchStyle.controlHover, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .help("Remover da lista")
        .accessibilityHidden(true)
    }

    private var tooltip: String {
        guard let quote, let previous = quote.previousClose else { return StockSymbol.display(symbol) }
        let close = StockFormat.price(previous, currency: quote.isIndex ? nil : quote.currency, fractionDigits: quote.fractionDigits)
        let change = StockFormat.absoluteChange(quote) ?? ""
        return String(localized: "\(quote.name) · Fechamento anterior \(close) · \(change) hoje")
    }

    private var accessibilityText: String {
        let shown = StockSymbol.display(symbol)
        guard let quote else { return "\(shown), \(subtitle)" }
        let change = quote.changeFraction.map { StockFormat.change($0) } ?? ""
        return "\(shown), \(quote.name), \(StockFormat.price(quote)), \(change)"
    }
}
