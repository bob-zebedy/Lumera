import CoreLocation
import os

final class LocationProvider: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    private static let maxLocationAge: TimeInterval = 5 * 60

    private let manager = CLLocationManager()
    private let enabledLock = OSAllocatedUnfairLock(initialState: false)

    var onStatusChange: @Sendable (CLAuthorizationStatus) -> Void = { _ in }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var currentLocation: CLLocation? {
        guard isEnabled else { return nil }
        guard let location = manager.location else { return nil }

        guard location.horizontalAccuracy >= 0 else { return nil }
        guard abs(location.timestamp.timeIntervalSinceNow) <= Self.maxLocationAge else { return nil }
        return location
    }

    private var isEnabled: Bool {
        enabledLock.withLock { $0 }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func setEnabled(_ on: Bool) {
        enabledLock.withLock { $0 = on }
        if on {
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
            default:
                break
            }
        } else {
            manager.stopUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let callback = onStatusChange
        DispatchQueue.main.async {
            callback(status)
        }
        guard isEnabled else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
