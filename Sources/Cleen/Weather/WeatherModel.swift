import CleenKit
import Foundation
import Observation

/// Current conditions and the forecast for the person's place.
///
/// The place and the last forecast are kept in UserDefaults, so the tab and the widget
/// show something the moment they open, even offline; a new forecast is fetched when the
/// one on screen is half an hour old.
@Observable
final class WeatherModel {
    private(set) var place: WeatherPlace?
    /// The last forecast for `place`; kept when a refresh fails.
    private(set) var forecast: Forecast?
    /// The saved place and forecast have been read back. Until then the views show
    /// nothing rather than flashing the "pick a city" state.
    private(set) var isRestored = false
    private(set) var isLoading = false
    /// The last request failed (offline, or a bad answer); `forecast` is the cached one.
    private(set) var lastRefreshFailed = false
    private(set) var isLocating = false
    private(set) var locationProblem: OneShotLocation.Problem?

    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var restoring: Task<Void, Never>?
    @ObservationIgnored private let locator = OneShotLocation()

    private nonisolated static let placeKey = "weather.place"
    private nonisolated static let forecastKey = "weather.forecast"

    init() {
        restoring = Task { [weak self] in await self?.restore() }
    }

    /// Refreshes when due, then every half hour, for as long as the calling view is on
    /// screen. Several views may watch at once; only one request is ever in flight.
    func watch() async {
        await restoring?.value
        while !Task.isCancelled {
            if place != nil, Date.now >= nextRefresh { await refresh() }
            let wait = place == nil ? 60 : nextRefresh.timeIntervalSinceNow
            try? await Task.sleep(for: .seconds(max(30, wait)))
        }
    }

    private var nextRefresh: Date {
        let fetchedAt = place.flatMap { place in forecast.flatMap { $0.isFor(place) ? $0.fetchedAt : nil } }
        return WeatherRefresh.nextRefresh(fetchedAt: fetchedAt, lastAttempt: lastAttempt, failed: lastRefreshFailed)
    }

    /// Asks for a new forecast now (the retry button, a new place).
    func refresh() async {
        guard let place, !isLoading else { return }
        isLoading = true
        lastAttempt = .now
        let result = await OpenMeteo.forecast(for: place)
        isLoading = false
        // The place changed while this was in flight: fetch the new one instead.
        guard place == self.place else {
            await refresh()
            return
        }
        switch result {
        case .success(let new):
            forecast = new
            lastRefreshFailed = false
            await Self.save(new, key: Self.forecastKey)
        case .failure:
            lastRefreshFailed = true
        }
    }

    /// Makes `place` the one the forecast is for, and fetches it.
    func choose(_ place: WeatherPlace) {
        self.place = place
        if let forecast, !forecast.isFor(place) { self.forecast = nil }
        lastRefreshFailed = false
        lastAttempt = nil
        locationProblem = nil
        Task {
            await Self.save(place, key: Self.placeKey)
            await refresh()
        }
    }

    /// One reading of the Mac's location, named by Apple's reverse geocoder, becomes the
    /// place. Runs on the model, not the view, so it finishes even if the panel closes
    /// while the permission prompt is up.
    func useCurrentLocation() {
        guard !isLocating else { return }
        isLocating = true
        locationProblem = nil
        Task {
            defer { isLocating = false }
            switch await locator.locate() {
            case .success(let place): choose(place)
            case .failure(let problem): locationProblem = problem
            }
        }
    }

    func dismissLocationProblem() {
        locationProblem = nil
    }

    // MARK: Persistence

    private func restore() async {
        let (place, forecast) = await offMain {
            (Self.load(WeatherPlace.self, key: Self.placeKey), Self.load(Forecast.self, key: Self.forecastKey))
        }
        // A place picked in the meantime wins over the saved one.
        if self.place == nil, let place {
            self.place = place
            if let forecast, forecast.isFor(place) { self.forecast = forecast }
        }
        isRestored = true
    }

    private static func save<Value: Encodable & Sendable>(_ value: Value, key: String) async {
        await offMain {
            guard let data = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private nonisolated static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
