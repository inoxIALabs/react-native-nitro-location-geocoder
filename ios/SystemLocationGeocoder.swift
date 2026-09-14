import CoreLocation
import Foundation

@MainActor
final class SystemLocationGeocoder: LocationGeocoding {
    private let geocoder = CLGeocoder()

    func reverseGeocode(
        latitude: Double,
        longitude: Double,
        preferredLocale: Locale?,
        completion: @escaping @MainActor @Sendable (GeocodingResponse) -> Void
    ) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
            let response: GeocodingResponse
            if let error {
                response = .failure(.failed(error.localizedDescription))
            } else if let placemark = placemarks?.first {
                // Copy framework objects into immutable values before the callback
                // crosses to the request's actor. No CLPlacemark or C++ result escapes.
                response = .success(GeocodedLocation(
                    countryCode: placemark.isoCountryCode ?? "",
                    country: placemark.country ?? "",
                    locality: placemark.locality ?? "",
                    administrativeArea: placemark.administrativeArea ?? "",
                    subAdministrativeArea: placemark.subAdministrativeArea ?? "",
                    subLocality: placemark.subLocality ?? ""
                ))
            } else {
                response = .failure(.noResults)
            }

            Task { @MainActor in
                completion(response)
            }
        }
    }

    func cancel() {
        geocoder.cancelGeocode()
    }
}
