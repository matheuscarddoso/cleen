import CleenKit
import SwiftUI

/// The left column of Tempo: where, how it is now in one large light figure, and in
/// words. The magnifier next to the city swaps the week for the city search.
struct WeatherNow: View {
    let place: WeatherPlace
    @Binding var isSearching: Bool
    @Environment(WeatherModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(place.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NotchStyle.secondary)
                    .lineLimit(1)
                    .help([place.name, place.subtitle].filter { !$0.isEmpty }.joined(separator: " — "))
                NotchIconButton(symbol: isSearching ? "xmark" : "magnifyingglass", help: isSearching ? "Fechar a busca" : "Trocar de cidade", isActive: isSearching) {
                    withAnimation(.smooth(duration: 0.25)) { isSearching.toggle() }
                }
            }
            .padding(.leading, -1)

            if let forecast = model.forecast {
                conditions(forecast)
            } else if model.lastRefreshFailed {
                unavailable
            } else {
                loading
            }
        }
        .animation(.smooth(duration: 0.3), value: model.forecast?.fetchedAt)
    }

    private func conditions(_ forecast: Forecast) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                WeatherSymbol(code: forecast.current.code, isDay: forecast.current.isDay, size: 32)
                Text(WeatherFormat.temperature(forecast.current.temperature))
                    .font(.system(size: 44, weight: .light).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.leading, -4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Agora: \(WeatherFormat.temperature(forecast.current.temperature)), \(forecast.current.weather.description)")
            Text(forecast.current.weather.description)
                .font(NotchStyle.bodyMedium)
                .foregroundStyle(NotchStyle.primary.opacity(0.85))
                .lineLimit(1)
            Text(footnote(forecast))
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.tertiary)
                .lineLimit(1)
                .contentTransition(.opacity)
                .padding(.top, 1)
        }
    }

    /// Feels-like and humidity normally; when the last refresh failed or the data is old,
    /// when it's from instead.
    private func footnote(_ forecast: Forecast) -> String {
        if model.lastRefreshFailed || WeatherRefresh.isStale(fetchedAt: forecast.fetchedAt, now: .now) {
            return forecast.updatedNote
        }
        var parts: [String] = []
        if let feels = forecast.current.apparentTemperature { parts.append("Sensação \(WeatherFormat.temperature(feels))") }
        if let humidity = forecast.current.humidity { parts.append("Umidade \(Int(humidity.rounded()))%") }
        return parts.joined(separator: " · ")
    }

    private var loading: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(.white)
            Text("Buscando a previsão…")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
        }
        .padding(.top, 14)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sem conexão com o serviço de previsão.")
                .font(NotchStyle.caption)
                .foregroundStyle(NotchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Tentar de novo") { Task { await model.refresh() } }
                .buttonStyle(.notchSecondary)
                .disabled(model.isLoading)
        }
        .padding(.top, 10)
    }
}
