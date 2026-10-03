import CoreLocation
import Observation

/// GPS is used to tag stations during setup, place pins on the mini-map, and as a coarse
/// checkpoint method (server-side geofence). It is never sent to other players, and indoors
/// it's only a rough hint. Sign recognition is the primary way to prove presence.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var location: CLLocation?
    /// Compass heading in degrees from true north (falls back to magnetic), for pointing players at signs.
    private(set) var heading: CLLocationDirection?
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
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// Bearing in degrees (0 = north, clockwise) from the current location to a station.
    func bearing(to station: Station) -> CLLocationDirection? {
        guard let from = location?.coordinate, let lat = station.lat, let lng = station.lng else { return nil }
        let φ1 = from.latitude * .pi / 180, φ2 = lat * .pi / 180
        let Δλ = (lng - from.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

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

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
