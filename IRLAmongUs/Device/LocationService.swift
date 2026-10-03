import CoreLocation
import Observation

/// GPS is used to tag stations during setup, place pins on the mini-map, and as a coarse
/// checkpoint method (server-side geofence). It is never sent to other players, and indoors
/// it's only a rough hint. Sign recognition is the primary way to prove presence.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var location: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
    }

    func start() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    func distance(to station: Station) -> CLLocationDistance? {
        guard let location, let lat = station.lat, let lng = station.lng else { return nil }
        return location.distance(from: CLLocation(latitude: lat, longitude: lng))
    }

    var statusMessage: String? {
        switch authorization {
        case .denied, .restricted: return "Location access denied. Enable it in Settings to see the map and use GPS check-ins."
        default: return nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
