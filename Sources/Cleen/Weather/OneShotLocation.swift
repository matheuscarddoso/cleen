import CleenKit
import CoreLocation
import MapKit

/// Asks for the Mac's location once and names it, for "Usar minha localização".
///
/// City-level accuracy is all a forecast needs, and it comes back faster (Wi-Fi only).
/// Each request gets a fresh `CLLocationManager`: a new manager reports its
/// authorization right after its delegate is set, which is what starts the request.
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    nonisolated enum Problem: Error, Equatable {
        /// Turned down, or Location Services are off.
        case denied
        /// Allowed, but no fix came back (no Wi-Fi around, timed out).
        case unavailable

        var message: String {
            switch self {
            case .denied: "O Cleen não tem acesso à localização."
            case .unavailable: "Não deu para encontrar sua localização agora."
            }
        }
    }

    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<Result<CLLocationCoordinate2D, Problem>, Never>?
    private var hasAskedForFix = false
    /// Tells a stale timeout from the current request's.
    private var request = 0

    func locate() async -> Result<WeatherPlace, Problem> {
        let fix = await withCheckedContinuation { continuation in
            self.continuation = continuation
            hasAskedForFix = false
            request += 1
            let current = request
            let manager = CLLocationManager()
            manager.desiredAccuracy = kCLLocationAccuracyKilometer
            manager.delegate = self
            self.manager = manager
            // Don't count on the delegate's first callback alone; asking twice is
            // harmless, `hasAskedForFix` keeps it to one fix.
            authorizationChanged(manager.authorizationStatus)
            // CoreLocation doesn't promise an answer if the prompt is left sitting.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard let self, self.request == current else { return }
                self.finish(.failure(.unavailable))
            }
        }
        switch fix {
        case .success(let coordinate): return .success(await Self.name(coordinate))
        case .failure(let problem): return .failure(problem)
        }
    }

    // CoreLocation calls back on the run loop the manager was made on: the main one.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated { authorizationChanged(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        MainActor.assumeIsolated { finish(.success(coordinate)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let denied = (error as? CLError)?.code == .denied
        MainActor.assumeIsolated { finish(.failure(denied ? .denied : .unavailable)) }
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        guard let manager, continuation != nil else { return }
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(.failure(.denied))
        default:
            guard !hasAskedForFix else { return }
            hasAskedForFix = true
            manager.requestLocation()
        }
    }

    private func finish(_ result: Result<CLLocationCoordinate2D, Problem>) {
        guard let continuation else { return }
        self.continuation = nil
        manager?.delegate = nil
        manager = nil
        continuation.resume(returning: result)
    }

    /// The city the coordinate is in, from Apple's reverse geocoder, in Portuguese.
    /// Without an answer (offline) the place is still usable, just generically named.
    private static func name(_ coordinate: CLLocationCoordinate2D) async -> WeatherPlace {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var city: String?
        var country: String?
        if let request = MKReverseGeocodingRequest(location: location) {
            request.preferredLocale = .cleen
            // The completion handler runs on the main actor; only the strings leave it
            // (map items aren't Sendable, so the async getter can't hand them over).
            (city, country) = await withCheckedContinuation { continuation in
                request.getMapItems { items, _ in
                    let address = items?.first?.addressRepresentations
                    continuation.resume(returning: (address?.cityName, address?.regionName))
                }
            }
        }
        return WeatherPlace(name: city ?? "Minha localização", country: country, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
