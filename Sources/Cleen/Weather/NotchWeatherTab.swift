import CleenKit
import SwiftUI

/// The Tempo tab, OmniNotch's Weather in Cleen's language: now on the left in one large
/// light figure, a hairline, then the week as seven columns. The city search opens in
/// the week's place, so the current weather stays in view while picking another.
struct NotchWeatherTab: View {
    @Environment(WeatherModel.self) private var model
    @State private var isSearching = false

    var body: some View {
        Group {
            if !model.isRestored {
                Color.clear
            } else if let place = model.place {
                HStack(alignment: .top, spacing: 16) {
                    WeatherNow(place: place, isSearching: $isSearching)
                        .padding(.leading, 4)
                        .frame(width: 176, alignment: .leading)
                    divider
                    trailing
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    intro
                        .padding(.leading, 4)
                        .frame(width: 176, alignment: .leading)
                    divider
                    WeatherSearchPanel(close: nil)
                }
            }
        }
        .padding(.top, 4)
        .task { await model.watch() }
        .onChange(of: model.place) { withAnimation(.smooth(duration: 0.25)) { isSearching = false } }
    }

    @ViewBuilder
    private var trailing: some View {
        if isSearching {
            WeatherSearchPanel { withAnimation(.smooth(duration: 0.25)) { isSearching = false } }
                .transition(.opacity)
        } else if let forecast = model.forecast {
            let today = forecast.today(at: .now)
            HStack(spacing: 2) {
                ForEach(forecast.upcomingDays(at: .now).prefix(7)) { day in
                    WeatherDayColumn(day: day, today: today)
                }
            }
            .transition(.opacity)
        } else {
            // The left column says what's happening; the week waits quietly.
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(NotchStyle.card)
                        .frame(maxWidth: .infinity)
                        .frame(height: 104)
                }
            }
            .opacity(model.isLoading ? 1 : 0.6)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(NotchStyle.separator)
            .frame(width: 1)
    }

    /// No place yet: what this is, next to the search that sets it up.
    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            WeatherSymbol(code: 2, size: 28)
                .padding(.leading, -4)
            Text("Escolha uma cidade")
                .font(NotchStyle.headline)
            Text("Busque pelo nome ou use sua localização para ver o tempo agora e nos próximos 7 dias.")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
