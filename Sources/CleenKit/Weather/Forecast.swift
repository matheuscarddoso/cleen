import Foundation

/// Conditions now and the days ahead for one place, as last fetched.
public struct Forecast: Codable, Equatable, Sendable {
    public struct Current: Codable, Equatable, Sendable {
        public var temperature: Double
        public var apparentTemperature: Double?
        /// Relative humidity, 0–100.
        public var humidity: Double?
        /// km/h.
        public var windSpeed: Double?
        public var code: Int
        public var isDay: Bool

        public init(temperature: Double, apparentTemperature: Double? = nil, humidity: Double? = nil, windSpeed: Double? = nil, code: Int, isDay: Bool) {
            self.temperature = temperature
            self.apparentTemperature = apparentTemperature
            self.humidity = humidity
            self.windSpeed = windSpeed
            self.code = code
            self.isDay = isDay
        }

        public var weather: WeatherCode { WeatherCode(code) }
    }

    public struct Day: Codable, Equatable, Sendable, Identifiable {
        /// `yyyy-MM-dd` in the place's own time zone, exactly as the API sends it.
        public var date: String
        public var code: Int
        public var high: Double
        public var low: Double
        /// Highest chance of rain in the day, 0–100.
        public var precipitationChance: Int?

        public init(date: String, code: Int, high: Double, low: Double, precipitationChance: Int? = nil) {
            self.date = date
            self.code = code
            self.high = high
            self.low = low
            self.precipitationChance = precipitationChance
        }

        public var id: String { date }
        public var weather: WeatherCode { WeatherCode(code) }
    }

    /// The place the request was made for (not the grid point the API snapped to), so a
    /// cached forecast can be matched to the saved place.
    public var latitude: Double
    public var longitude: Double
    public var current: Current
    public var days: [Day]
    /// IANA identifier of the place's time zone ("America/Sao_Paulo").
    public var timeZone: String
    public var utcOffsetSeconds: Int
    public var fetchedAt: Date

    public init(latitude: Double, longitude: Double, current: Current, days: [Day], timeZone: String, utcOffsetSeconds: Int, fetchedAt: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.current = current
        self.days = days
        self.timeZone = timeZone
        self.utcOffsetSeconds = utcOffsetSeconds
        self.fetchedAt = fetchedAt
    }

    public func isFor(_ place: WeatherPlace) -> Bool {
        abs(latitude - place.latitude) < 0.001 && abs(longitude - place.longitude) < 0.001
    }

    /// The place's time zone: by name when the system knows it, else the fixed offset.
    public var placeTimeZone: TimeZone {
        TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .gmt
    }

    /// Today's date at the place, in the API's `yyyy-MM-dd` form. A forecast for Tokyo
    /// opened in São Paulo starts on Tokyo's today.
    public func today(at now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = placeTimeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Days from today on. A cached forecast opened the next morning drops yesterday
    /// instead of calling it "Hoje".
    public func upcomingDays(at now: Date) -> [Day] {
        let today = today(at: now)
        // Same fixed-width format, so string order is date order.
        return days.filter { $0.date >= today }
    }

    /// Today's row, when the forecast still has one.
    public func todayDay(at now: Date) -> Day? {
        let today = today(at: now)
        return days.first { $0.date == today }
    }
}
