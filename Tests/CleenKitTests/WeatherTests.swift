import Foundation
import Testing
@testable import CleenKit

struct WeatherTests {
    private let saoPaulo = WeatherPlace(name: "São Paulo", region: "São Paulo", country: "Brasil", latitude: -23.5475, longitude: -46.63611)

    private let forecastJSON = """
    {"latitude":-23.5,"longitude":-46.625,"generationtime_ms":0.1,"utc_offset_seconds":-10800,
     "timezone":"America/Sao_Paulo","timezone_abbreviation":"GMT-3","elevation":760.0,
     "current_units":{"time":"iso8601","temperature_2m":"°C"},
     "current":{"time":"2026-10-23T14:15","interval":900,"temperature_2m":24.6,"weather_code":2,"is_day":1,
                "apparent_temperature":25.1,"relative_humidity_2m":61,"wind_speed_10m":11.2},
     "daily_units":{"time":"iso8601"},
     "daily":{"time":["2026-10-23","2026-10-24","2026-10-25","2026-10-26","2026-10-27","2026-10-28","2026-10-29"],
              "weather_code":[2,61,null,3,0,80,95],
              "temperature_2m_max":[27.9,22.1,20.0,24.4,29.0,26.5,25.2],
              "temperature_2m_min":[17.2,16.4,15.0,15.8,18.1,18.9,17.7],
              "precipitation_probability_max":[10,85,40,null,0,60,90]}}
    """

    // MARK: Codes

    @Test(arguments: [
        (0, "Céu limpo", "sun.max.fill", "moon.stars.fill"),
        (2, "Parcialmente nublado", "cloud.sun.fill", "cloud.moon.fill"),
        (3, "Nublado", "cloud.fill", "cloud.fill"),
        (45, "Neblina", "cloud.fog.fill", "cloud.fog.fill"),
        (61, "Chuva fraca", "cloud.rain.fill", "cloud.rain.fill"),
        (65, "Chuva forte", "cloud.heavyrain.fill", "cloud.heavyrain.fill"),
        (80, "Pancadas de chuva fracas", "cloud.sun.rain.fill", "cloud.moon.rain.fill"),
        (75, "Neve forte", "cloud.snow.fill", "cloud.snow.fill"),
        (95, "Trovoada", "cloud.bolt.rain.fill", "cloud.bolt.rain.fill"),
        (99, "Trovoada com granizo forte", "cloud.hail.fill", "cloud.hail.fill"),
    ])
    func codes(code: Int, description: String, day: String, night: String) {
        let weather = WeatherCode(code)
        #expect(weather.description == description)
        #expect(weather.symbol(isDay: true) == day)
        #expect(weather.symbol(isDay: false) == night)
    }

    @Test func everyDocumentedCodeHasWords() {
        let documented = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        for code in documented {
            #expect(WeatherCode(code).description != "Tempo indefinido", "code \(code)")
        }
        #expect(WeatherCode(42).description == "Tempo indefinido")
        #expect(WeatherCode(42).symbol() == "cloud.fill")
    }

    // MARK: Forecast parsing

    @Test func parsesForecast() throws {
        let fetched = Date(timeIntervalSince1970: 1_800_000_000)
        let forecast = try #require(OpenMeteo.parseForecast(Data(forecastJSON.utf8), for: saoPaulo, fetchedAt: fetched))
        #expect(forecast.current == Forecast.Current(temperature: 24.6, apparentTemperature: 25.1, humidity: 61, windSpeed: 11.2, code: 2, isDay: true))
        #expect(forecast.timeZone == "America/Sao_Paulo")
        #expect(forecast.utcOffsetSeconds == -10800)
        #expect(forecast.fetchedAt == fetched)
        // The requested place, not the API's grid point.
        #expect(forecast.latitude == saoPaulo.latitude)
        #expect(forecast.isFor(saoPaulo))
        // The day with a null code is skipped; a null rain chance is kept as unknown.
        #expect(forecast.days.map(\.date) == ["2026-10-23", "2026-10-24", "2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29"])
        #expect(forecast.days[1] == Forecast.Day(date: "2026-10-24", code: 61, high: 22.1, low: 16.4, precipitationChance: 85))
        #expect(forecast.days[2].precipitationChance == nil)
    }

    @Test func nightAndMissingExtras() throws {
        let json = """
        {"current":{"temperature_2m":-0.4,"weather_code":0,"is_day":0},
         "daily":{"time":["2026-01-01"],"weather_code":[0],"temperature_2m_max":[3],"temperature_2m_min":[-5]}}
        """
        let forecast = try #require(OpenMeteo.parseForecast(Data(json.utf8), for: saoPaulo, fetchedAt: .now))
        #expect(forecast.current.isDay == false)
        #expect(forecast.current.apparentTemperature == nil)
        #expect(forecast.days.first?.precipitationChance == nil)
        #expect(forecast.timeZone == "GMT")
    }

    @Test(arguments: ["", "not json", #"{"error":true,"reason":"Latitude must be in range"}"#, #"{"current":{"weather_code":1},"daily":{"time":[],"weather_code":[],"temperature_2m_max":[],"temperature_2m_min":[]}}"#])
    func rejectsBrokenForecasts(json: String) {
        #expect(OpenMeteo.parseForecast(Data(json.utf8), for: saoPaulo, fetchedAt: .now) == nil)
    }

    @Test func forecastSurvivesTheCache() throws {
        let forecast = try #require(OpenMeteo.parseForecast(Data(forecastJSON.utf8), for: saoPaulo, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)))
        let data = try JSONEncoder().encode(forecast)
        #expect(try JSONDecoder().decode(Forecast.self, from: data) == forecast)
    }

    // MARK: Days

    @Test func todayFollowsThePlace() throws {
        let forecast = try #require(OpenMeteo.parseForecast(Data(forecastJSON.utf8), for: saoPaulo, fetchedAt: .now))
        // 2026-10-24 01:30 UTC is still the 23rd in São Paulo (UTC−3).
        let lateEvening = Date(timeIntervalSince1970: 1_792_805_400)
        #expect(forecast.today(at: lateEvening) == "2026-10-23")
        #expect(forecast.upcomingDays(at: lateEvening).count == 6)
        #expect(forecast.todayDay(at: lateEvening)?.high == 27.9)

        // Two days later it's the 25th there, a day the response had no data for: the
        // list starts on the 26th and there's no today row.
        let later = lateEvening + 2 * 86_400
        #expect(forecast.upcomingDays(at: later).first?.date == "2026-10-26")
        #expect(forecast.todayDay(at: later) == nil)
    }

    @Test func dayLabels() {
        #expect(WeatherFormat.dayLabel("2026-10-23", today: "2026-10-23") == "Hoje")
        #expect(WeatherFormat.dayLabel("2026-10-24", today: "2026-10-23") == "Sáb")
        #expect(WeatherFormat.dayLabel("2026-10-25", today: "2026-10-23") == "Dom")
        #expect(WeatherFormat.dayLabel("2026-10-26", today: "2026-10-23") == "Seg")
        #expect(WeatherFormat.dayLabel("2024-02-29", today: "2026-10-23") == "Qui")
        #expect(WeatherFormat.dayLabel("1969-12-31", today: "2026-10-23") == "Qua")
        #expect(WeatherFormat.dayLabel("garbage", today: "2026-10-23") == "—")
        #expect(WeatherFormat.longDayLabel("2026-10-24", today: "2026-10-23") == "Amanhã")
        #expect(WeatherFormat.longDayLabel("2026-11-01", today: "2026-10-31") == "Amanhã")
        #expect(WeatherFormat.longDayLabel("2026-10-27", today: "2026-10-23") == "Terça")
    }

    @Test(arguments: [(24.6, "25°"), (24.4, "24°"), (-0.4, "0°"), (-3.6, "-4°"), (0, "0°")])
    func temperatures(celsius: Double, text: String) {
        #expect(WeatherFormat.temperature(celsius) == text)
    }

    // MARK: Geocoding

    @Test func parsesSearch() throws {
        let json = """
        {"results":[
          {"id":3448439,"name":"São Paulo","latitude":-23.5475,"longitude":-46.63611,"country_code":"BR","admin1":"São Paulo","country":"Brasil"},
          {"id":1,"name":"São Paulo","latitude":-23.6,"longitude":-46.7,"country_code":"BR","admin1":"São Paulo","country":"Brasil"},
          {"id":2,"name":"Sao Paulo","latitude":7.0,"longitude":-74.0,"country":"Colômbia"},
          {"id":3,"name":"  ","latitude":0,"longitude":0}
        ],"generationtime_ms":1.2}
        """
        let places = try #require(OpenMeteo.parseSearch(Data(json.utf8)))
        #expect(places == [
            saoPaulo,
            WeatherPlace(name: "Sao Paulo", region: nil, country: "Colômbia", latitude: 7, longitude: -74),
        ])
        #expect(places[0].subtitle == "São Paulo, Brasil")
        #expect(places[1].subtitle == "Colômbia")
    }

    @Test func emptySearch() throws {
        #expect(try #require(OpenMeteo.parseSearch(Data(#"{"generationtime_ms":0.4}"#.utf8))).isEmpty)
        #expect(OpenMeteo.parseSearch(Data("<html>".utf8)) == nil)
    }

    @Test func shortQueriesDontHitTheNetwork() async throws {
        #expect(try await OpenMeteo.search(" a ").get().isEmpty)
    }

    // MARK: URLs

    @Test func urls() {
        let forecast = OpenMeteo.forecastURL(latitude: -23.5475, longitude: -46.63611).absoluteString
        #expect(forecast.hasPrefix("https://api.open-meteo.com/v1/forecast?latitude=-23.5475&longitude=-46.6361&current=temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7"))
        let search = OpenMeteo.searchURL(name: "São José dos Campos").absoluteString
        #expect(search == "https://geocoding-api.open-meteo.com/v1/search?name=S%C3%A3o%20Jos%C3%A9%20dos%20Campos&count=6&language=pt")
    }

    // MARK: Refresh

    @Test func refreshSchedule() {
        let fetched = Date(timeIntervalSince1970: 1_000_000)
        #expect(WeatherRefresh.nextRefresh(fetchedAt: nil, lastAttempt: nil, failed: false) == .distantPast)
        #expect(WeatherRefresh.nextRefresh(fetchedAt: fetched, lastAttempt: fetched, failed: false) == fetched + 1800)
        // A failure long after the fetch waits five minutes, not zero.
        let attempt = fetched + 3600
        #expect(WeatherRefresh.nextRefresh(fetchedAt: fetched, lastAttempt: attempt, failed: true) == attempt + 300)
        #expect(WeatherRefresh.nextRefresh(fetchedAt: nil, lastAttempt: attempt, failed: true) == attempt + 300)
        #expect(!WeatherRefresh.isStale(fetchedAt: fetched, now: fetched + 1800))
        #expect(WeatherRefresh.isStale(fetchedAt: fetched, now: fetched + 7200))
    }

    @Test func sameSpot() {
        var renamed = saoPaulo
        renamed.name = "Minha localização"
        #expect(renamed.isSameSpot(as: saoPaulo))
        renamed.latitude += 0.01
        #expect(!renamed.isSameSpot(as: saoPaulo))
    }
}
