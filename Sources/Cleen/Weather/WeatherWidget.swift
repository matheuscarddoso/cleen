import CleenKit
import SwiftUI

/// The weather on Início: the sky and the temperature, the words and the day's range
/// when there's room, the next three days at the largest size. A tap opens Tempo.
struct WeatherWidget: View {
    let size: HomeWidgetSize
    @Environment(WeatherModel.self) private var model
    @Environment(NotchState.self) private var state

    var body: some View {
        Button { state.tab = .weather } label: {
            Group {
                if !model.isRestored {
                    Color.clear
                } else if let place = model.place, let forecast = model.forecast {
                    switch size {
                    case .small: small(place, forecast)
                    case .medium: medium(place, forecast)
                    case .large:
                        HStack(spacing: 12) {
                            medium(place, forecast)
                            Rectangle()
                                .fill(NotchStyle.separator)
                                .frame(width: 1)
                                .padding(.vertical, 6)
                            nextDays(forecast)
                        }
                    }
                } else {
                    placeholder
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Abrir o Tempo")
        .task { await model.watch() }
    }

    // MARK: Sizes

    private func small(_ place: WeatherPlace, _ forecast: Forecast) -> some View {
        VStack(spacing: 0) {
            WeatherSymbol(code: forecast.current.code, isDay: forecast.current.isDay, size: 24)
            Text(WeatherFormat.temperature(forecast.current.temperature))
                .font(.system(size: 22, weight: .light).monospacedDigit())
                .contentTransition(.numericText())
            Text(place.name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(NotchStyle.secondary)
                .lineLimit(1)
        }
        .frame(width: 84, height: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo em \(place.name): \(WeatherFormat.temperature(forecast.current.temperature)), \(forecast.current.weather.description)")
    }

    private func medium(_ place: WeatherPlace, _ forecast: Forecast) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HomeWidgetLabel(title: place.name, symbol: "location.fill")
            HStack(spacing: 6) {
                WeatherSymbol(code: forecast.current.code, isDay: forecast.current.isDay, size: 22)
                    .padding(.leading, -3)
                Text(WeatherFormat.temperature(forecast.current.temperature))
                    .font(.system(size: 28, weight: .light).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(forecast.current.weather.description)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NotchStyle.primary.opacity(0.85))
            Text(rangeLine(forecast))
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(NotchStyle.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The three days after today, as compact columns.
    private func nextDays(_ forecast: Forecast) -> some View {
        let today = forecast.today(at: .now)
        return HStack(spacing: 10) {
            ForEach(forecast.upcomingDays(at: .now).filter { $0.date != today }.prefix(3)) { day in
                VStack(spacing: 3) {
                    Text(WeatherFormat.dayLabel(day.date, today: today))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(NotchStyle.secondary)
                    WeatherSymbol(code: day.code, size: 16)
                    Text(WeatherFormat.temperature(day.high))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    Text(WeatherFormat.temperature(day.low))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(NotchStyle.secondary)
                }
                .lineLimit(1)
                .frame(minWidth: 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(WeatherFormat.longDayLabel(day.date, today: today)): \(day.weather.description), máxima \(WeatherFormat.temperature(day.high)), mínima \(WeatherFormat.temperature(day.low))")
            }
        }
        .fixedSize()
    }

    /// "Máx 28° · Mín 17°" for today, or the last update when the data is behind.
    private func rangeLine(_ forecast: Forecast) -> String {
        if model.lastRefreshFailed || WeatherRefresh.isStale(fetchedAt: forecast.fetchedAt, now: .now) {
            return forecast.updatedNote
        }
        guard let day = forecast.todayDay(at: .now) else { return "" }
        return "Máx \(WeatherFormat.temperature(day.high)) · Mín \(WeatherFormat.temperature(day.low))"
    }

    // MARK: Without a forecast

    /// No place yet, or the first forecast is on its way (or failed).
    @ViewBuilder
    private var placeholder: some View {
        let title = model.place?.name ?? "Tempo"
        let message = model.place == nil ? "Escolha uma cidade" : (model.lastRefreshFailed ? "Sem conexão" : "Buscando…")
        switch size {
        case .small:
            VStack(spacing: 4) {
                WeatherSymbol(code: 2, size: 24)
                Text(message)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 84, height: 84)
        case .medium, .large:
            VStack(alignment: .leading, spacing: 4) {
                HomeWidgetLabel(title: title, symbol: model.place == nil ? "cloud.sun" : "location.fill")
                HStack(spacing: 8) {
                    WeatherSymbol(code: 2, size: 22)
                        .padding(.leading, -3)
                        .opacity(model.place == nil ? 1 : 0.5)
                    Text(model.place == nil ? "Escolha uma cidade para ver a previsão." : message)
                        .font(.system(size: 11))
                        .foregroundStyle(NotchStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
