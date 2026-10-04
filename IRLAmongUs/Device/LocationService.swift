import CoreLocation
import Observation
import UIKit

/// GPS is used to tag stations during setup, place pins on the mini-map, and as a coarse
/// checkpoint method (server-side geofence). Indoors it's only a rough hint; sign recognition is
/// the primary way to prove presence. It also feeds `PositionEstimator`, whose estimate is only
/// sent to the server while live positions (testing) are turned on.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var location: CLLocation?
    /// Compass heading in degrees from true north (falls back to magnetic), for pointing players at signs.
    private(set) var heading: CLLocationDirection?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let manager = CLLocationManager()
    /// Every fix and heading, for the position estimator.
    @ObservationIgnored var onLocation: ((CLLocation) -> Void)?
    @ObservationIgnored var onHeading: ((CLHeading) -> Void)?
    @ObservationIgnored private var orientationCheckedAt = Date.distantPast

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
        locations.forEach { onLocation?($0) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        onHeading?(newHeading)
        matchHeadingToScreen()
    }

    /// Headings are measured toward the top of the screen as the player sees it (the game is landscape).
    private func matchHeadingToScreen() {
        guard Date().timeIntervalSince(orientationCheckedAt) > 2 else { return }
        orientationCheckedAt = Date()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        // Interface and device orientation name landscape the opposite way round.
        let orientation: CLDeviceOrientation = switch scene?.interfaceOrientation {
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        case .portraitUpsideDown: .portraitUpsideDown
        default: .portrait
        }
        if manager.headingOrientation != orientation { manager.headingOrientation = orientation }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}
