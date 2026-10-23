import Foundation

/// Open-Meteo's forecast and geocoding APIs: free, no key, no account. These two
/// endpoints are the only network calls the Tempo tab makes.
public enum OpenMeteo {
    public enum Failure: Error, Equatable {
        /// No connection, timeout, DNS: worth trying again later.
        case offline
        /// The server answered with something that isn't a forecast.
        case badResponse
    }

    // MARK: URLs

    public static func forecastURL(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: coordinate(latitude)),
            URLQueryItem(name: "longitude", value: coordinate(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        return components.url!
    }

    public static func searchURL(name: String) -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "pt"),
        ]
        return components.url!
    }

    /// Four decimals (~11 m) with a dot whatever the system locale; `String(format:)`
    /// without a locale is POSIX.
    private static func coordinate(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    // MARK: Fetching

    @concurrent
    public static func forecast(for place: WeatherPlace, now: Date = .now) async -> Result<Forecast, Failure> {
        var request = URLRequest(url: forecastURL(latitude: place.latitude, longitude: place.longitude), timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        switch await load(request) {
        case .success(let data):
            guard let forecast = parseForecast(data, for: place, fetchedAt: now) else { return .failure(.badResponse) }
            return .success(forecast)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    /// Up to six places matching `name`. Under two letters the API answers nothing, so
    /// that's answered here without asking.
    @concurrent
    public static func search(_ name: String) async -> Result<[WeatherPlace], Failure> {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return .success([]) }
        let request = URLRequest(url: searchURL(name: query), timeoutInterval: 10)
        switch await load(request) {
        case .success(let data):
            guard let places = parseSearch(data) else { return .failure(.badResponse) }
            return .success(places)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private static func load(_ request: URLRequest) async -> Result<Data, Failure> {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .failure(.badResponse) }
            return .success(data)
        } catch {
            return .failure(.offline)
        }
    }

    // MARK: Parsing

    /// Reads a forecast response. `nil` when the essentials (current temperature and
    /// code, the daily arrays) are missing; a day with a gap in it is skipped rather
    /// than shown with made-up numbers.
    public static func parseForecast(_ data: Data, for place: WeatherPlace, fetchedAt: Date) -> Forecast? {
        guard let raw = try? JSONDecoder().decode(RawForecast.self, from: data),
              let temperature = raw.current.temperature_2m,
              let code = raw.current.weather_code
        else { return nil }

        let daily = raw.daily
        var days: [Forecast.Day] = []
        for (index, date) in daily.time.enumerated() {
            guard let code = daily.weather_code[safe: index] ?? nil,
                  let high = daily.temperature_2m_max[safe: index] ?? nil,
                  let low = daily.temperature_2m_min[safe: index] ?? nil
            else { continue }
            let chance = (daily.precipitation_probability_max?[safe: index] ?? nil).map { Int($0.rounded()) }
            days.append(Forecast.Day(date: date, code: code, high: high, low: low, precipitationChance: chance))
        }

        return Forecast(
            latitude: place.latitude,
            longitude: place.longitude,
            current: Forecast.Current(
                temperature: temperature,
                apparentTemperature: raw.current.apparent_temperature,
                humidity: raw.current.relative_humidity_2m,
                windSpeed: raw.current.wind_speed_10m,
                code: code,
                isDay: (raw.current.is_day ?? 1) != 0
            ),
            days: days,
            timeZone: raw.timezone ?? "GMT",
            utcOffsetSeconds: raw.utc_offset_seconds ?? 0,
            fetchedAt: fetchedAt
        )
    }

    /// Reads a geocoding response. No `results` key is how the API says "nothing found",
    /// so that's an empty list, not a failure. Identical entries (same name, region and
    /// country) are folded into the first.
    public static func parseSearch(_ data: Data) -> [WeatherPlace]? {
        guard let raw = try? JSONDecoder().decode(RawSearch.self, from: data) else { return nil }
        var seen = Set<String>()
        var places: [WeatherPlace] = []
        for result in raw.results ?? [] {
            let name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let place = WeatherPlace(name: name, region: result.admin1, country: result.country, latitude: result.latitude, longitude: result.longitude)
            guard seen.insert("\(name)|\(place.subtitle)").inserted else { continue }
            places.append(place)
        }
        return places
    }

    // Field names mirror the API's snake_case keys.
    private struct RawForecast: Decodable {
        struct Current: Decodable {
            var temperature_2m: Double?
            var weather_code: Int?
            var is_day: Int?
            var apparent_temperature: Double?
            var relative_humidity_2m: Double?
            var wind_speed_10m: Double?
        }

        struct Daily: Decodable {
            var time: [String]
            var weather_code: [Int?]
            var temperature_2m_max: [Double?]
            var temperature_2m_min: [Double?]
            var precipitation_probability_max: [Double?]?
        }

        var timezone: String?
        var utc_offset_seconds: Int?
        var current: Current
        var daily: Daily
    }

    private struct RawSearch: Decodable {
        struct Result: Decodable {
            var name: String
            var latitude: Double
            var longitude: Double
            var country: String?
            var admin1: String?
        }

        var results: [Result]?
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
