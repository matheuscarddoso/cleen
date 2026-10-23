/// Where the forecast is for: a geocoding result or the Mac's own location.
public struct WeatherPlace: Codable, Hashable, Sendable {
    public var name: String
    /// State or province ("São Paulo", "Minas Gerais"); absent for some places.
    public var region: String?
    public var country: String?
    public var latitude: Double
    public var longitude: Double

    public init(name: String, region: String? = nil, country: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// "Minas Gerais, Brasil": what tells two Santa Marias apart in the results.
    public var subtitle: String {
        [region, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Two places within ~100 m are the same place for a forecast. Compares coordinates
    /// only, so a renamed place keeps its cached forecast.
    public func isSameSpot(as other: WeatherPlace) -> Bool {
        abs(latitude - other.latitude) < 0.001 && abs(longitude - other.longitude) < 0.001
    }
}
