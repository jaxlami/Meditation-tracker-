import Foundation
import CoreLocation

/// Looks up a readable place name ("Central Park, New York") for the current location.
final class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var placeName: String?
    @Published var isLocating = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var waitingForPermission = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPlaceName() {
        errorMessage = nil
        placeName = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            waitingForPermission = true
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access is off. You can turn it on in the Settings app."
        default:
            isLocating = true
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForPermission else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            waitingForPermission = false
            manager.requestLocation()
        case .denied, .restricted:
            waitingForPermission = false
            isLocating = false
            errorMessage = "Location access is off. You can turn it on in the Settings app."
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLocating = false
                if let placemark = placemarks?.first {
                    self.placeName = Self.describe(placemark)
                } else {
                    self.errorMessage = "Couldn't find a name for this place."
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            self.errorMessage = "Couldn't get your location."
        }
    }

    private static func describe(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let poi = placemark.areasOfInterest?.first {
            parts.append(poi)
        } else if let name = placemark.name {
            parts.append(name)
        }
        if let city = placemark.locality, !parts.contains(city) {
            parts.append(city)
        }
        return parts.joined(separator: ", ")
    }
}
