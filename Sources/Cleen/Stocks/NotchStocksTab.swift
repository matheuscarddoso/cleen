import CleenKit
import SwiftUI

/// The Ações tab, OmniNotch's Stocks in Cleen's language: a ticker search with a +
/// on top, then the watchlist as cards (ticker and company, today's line, price and the
/// day's change), two or three to a row as the panel widens. Typing swaps the list for
/// the search hits; ↑ ↓ move, Return adds, Esc goes back to the list. Drag a card onto
/// another to reorder.
struct NotchStocksTab: View {
    @Environment(StocksModel.self) private var model
    @State private var query = ""
    @State private var results: [StockSearchResult] = []
    @State private var searchStatus = SearchStatus.idle
    @State private var selection = 0
    /// A one-line answer to the last add ("Não encontrei XYZ"), cleared by typing.
    @State private var notice: String?
    @FocusState private var fieldFocused: Bool

    private enum SearchStatus: Equatable {
        case idle
        case searching
        case done
        case failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Group {
                if !model.isRestored {
                    Color.clear
                } else if isSearching {
                    searchContent
                        .transition(.opacity)
                } else if model.symbols.isEmpty {
                    empty
                        .transition(.opacity)
                } else {
                    watchlist
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.top, 4)
        .animation(.smooth(duration: 0.2), value: isSearching)
        .onKeyPress(.upArrow) { move(by: -1) }
        .onKeyPress(.downArrow) { move(by: 1) }
        .onKeyPress(.escape) {
            guard !query.isEmpty else { return .ignored }
            query = ""
            return .handled
        }
        .task { await model.watch() }
        .task(id: query) { await search() }
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.2)) { notice = nil }
        }
        // Focus once the tab has settled, as the clipboard search does: becoming first
        // responder on the tab's first frame stalled the switch.
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocused = true
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 6) {
            field
            addButton
            Spacer(minLength: 12)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                status(at: context.date)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(NotchStyle.tertiary)
            TextField("Buscar código ou empresa", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($fieldFocused)
                .onSubmit(addCurrent)
            if searchStatus == .searching {
                ProgressView().controlSize(.mini).tint(.white)
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar")
                .accessibilityLabel("Limpar a busca")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 230, height: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(NotchStyle.primary.opacity(fieldFocused ? 0.28 : 0.18))
        }
        .animation(.smooth(duration: 0.15), value: fieldFocused)
    }

    private var addButton: some View {
        Button(action: addCurrent) {
            Group {
                if model.adding != nil {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(.rect)
        }
        .buttonStyle(StockSquareButtonStyle())
        .disabled(!isSearching || model.adding != nil)
        .help("Adicionar à lista")
        .accessibilityLabel("Adicionar à lista")
    }

    /// Quiet, on the right: what went wrong with the last add, otherwise whether the
    /// numbers are live.
    @ViewBuilder
    private func status(at now: Date) -> some View {
        let parts = statusParts(at: now)
        if let notice {
            Label(notice, systemImage: "exclamationmark.circle")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(NotchStyle.warning)
        } else if !parts.isEmpty {
            HStack(spacing: 5) {
                if model.allMarketsClosed(at: now) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 9))
                }
                Text(parts.joined(separator: " · "))
            }
            .foregroundStyle(NotchStyle.tertiary)
        }
    }

    private func statusParts(at now: Date) -> [String] {
        var parts: [String] = []
        if model.allMarketsClosed(at: now) { parts.append(String(localized: "Mercado fechado")) }
        if model.isBehind(at: now), let update = model.lastUpdate { parts.append(Self.updatedNote(update)) }
        return parts
    }

    static func updatedNote(_ date: Date) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.cleen))
        if Calendar.current.isDateInToday(date) { return String(localized: "Atualizado às \(time)") }
        let day = date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.cleen))
        return String(localized: "Atualizado em \(day) às \(time)")
    }

    // MARK: Watchlist

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 270), spacing: 8)]
    }

    private var watchlist: some View {
        NotchScroll {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                let allClosed = model.allMarketsClosed(at: .now)
                ForEach(model.symbols, id: \.self) { symbol in
                    let quote = model.quotes[symbol]
                    StockRow(
                        symbol: symbol,
                        quote: quote,
                        isUnknown: model.unknown.contains(symbol),
                        showsClosed: !allClosed && quote.map { !$0.isMarketOpen(at: .now) } == true
                    )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.smooth(duration: 0.25), value: model.symbols)
            .padding(.bottom, 4)
        }
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(NotchStyle.tertiary)
                .padding(.bottom, 4)
            Text("Nenhuma ação na lista")
                .font(NotchStyle.headline)
            Text("Busque um código, como PETR4 ou AAPL, e adicione com +.")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Search

    @ViewBuilder
    private var searchContent: some View {
        if results.isEmpty {
            Text(searchHint)
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.tertiary)
                .padding(.leading, 2)
                .contentTransition(.opacity)
        } else {
            // Two columns: six hits fit in three rows, no scrolling at the default size.
            let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    StockSearchRow(
                        result: result,
                        isSelected: index == selection,
                        isListed: model.symbols.contains(result.symbol),
                        isAdding: model.adding == result.symbol
                    ) { add(result.symbol, verified: true) }
                }
            }
        }
    }

    private var searchHint: String {
        switch searchStatus {
        case .idle, .searching: String(localized: "Buscando…")
        case .done:
            if let symbol = StockSymbol.lookup(query) {
                String(localized: "Nada encontrado. Return tenta \(StockSymbol.display(symbol)) direto.")
            } else {
                String(localized: "Nada encontrado com esse nome.")
            }
        case .failed: String(localized: "Sem conexão para buscar agora.")
        }
    }

    /// Waits for a pause in typing, so a name is one request rather than one per letter;
    /// a newer query cancels this one.
    private func search() async {
        notice = nil
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = []
            searchStatus = .idle
            return
        }
        searchStatus = .searching
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        let result = await YahooFinance.search(text)
        guard !Task.isCancelled else { return }
        switch result {
        case .success(let found):
            withAnimation(.smooth(duration: 0.2)) { results = found }
            selection = 0
            searchStatus = .done
        case .failure:
            results = []
            searchStatus = .failed
        }
    }

    private func move(by step: Int) -> KeyPress.Result {
        guard isSearching, !results.isEmpty else { return .ignored }
        selection = min(max(selection + step, 0), results.count - 1)
        return .handled
    }

    /// Return and +: the highlighted hit, or the typed ticker as is when the search
    /// found nothing (or hasn't answered yet).
    private func addCurrent() {
        guard isSearching else { return }
        if searchStatus == .done, results.indices.contains(selection) {
            add(results[selection].symbol, verified: true)
        } else if let symbol = StockSymbol.lookup(query) {
            add(symbol, verified: false)
        } else {
            notice = String(localized: "Código inválido")
        }
    }

    private func add(_ symbol: String, verified: Bool) {
        Task {
            let outcome = await model.add(symbol, verified: verified)
            let shown = StockSymbol.display(symbol)
            switch outcome {
            case .added:
                query = ""
            case .alreadyListed:
                notice = String(localized: "\(shown) já está na lista")
            case .full:
                notice = String(localized: "A lista já tem \(StockSymbol.maximumCount) ações")
            case .notFound:
                notice = String(localized: "Não encontrei \(shown)")
            case .offline:
                notice = String(localized: "Sem conexão para buscar \(shown)")
            case .busy:
                break
            }
        }
    }
}

/// The + next to the search: a square version of the grey pill.
private struct StockSquareButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NotchStyle.primary)
            .background(configuration.isPressed || isHovered ? NotchStyle.controlHover : NotchStyle.control, in: .rect(cornerRadius: 7, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .onHover { isHovered = $0 }
            .animation(.smooth(duration: 0.15), value: isHovered)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

/// One search hit: the ticker, the company, the exchange; a check when it's already on
/// the list.
private struct StockSearchRow: View {
    let result: StockSearchResult
    let isSelected: Bool
    let isListed: Bool
    let isAdding: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(result.displaySymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(minWidth: 48, alignment: .leading)
                    .layoutPriority(1)
                Text(result.name)
                    .font(NotchStyle.caption)
                    .foregroundStyle(NotchStyle.secondary)
                Spacer(minLength: 4)
                if let exchange = result.exchange {
                    Text(exchange)
                        .font(NotchStyle.caption)
                        .foregroundStyle(NotchStyle.tertiary)
                }
                Group {
                    if isAdding {
                        ProgressView().controlSize(.mini).tint(.white)
                    } else {
                        Image(systemName: isListed ? "checkmark" : "plus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isListed ? NotchStyle.good : (isSelected || isHovered ? NotchStyle.primary : NotchStyle.tertiary))
                    }
                }
                .frame(width: 14)
            }
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(background, in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isListed)
        .onHover { isHovered = $0 }
        .animation(.smooth(duration: 0.12), value: isHovered)
        .accessibilityLabel("\(result.displaySymbol), \(result.name)")
        .accessibilityHint(isListed ? String(localized: "Já está na lista") : String(localized: "Adicionar à lista"))
    }

    private var background: Color {
        if isSelected { return NotchStyle.selection }
        return isHovered ? NotchStyle.control.opacity(0.6) : .clear
    }
}
