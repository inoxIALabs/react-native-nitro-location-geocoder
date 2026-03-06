import Foundation
import CoreLocation
import NitroModules

class HybridLocationGeocoder: HybridLocationGeocoderSpec {

    private let geocoder = CLGeocoder()

    private func preferredLocale(_ locale: String) -> Locale? {
        let normalized = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }
        return Locale(identifier: normalized)
    }

    func reverseGeocode(latitude: Double, longitude: Double, locale: String) throws -> Promise<LocationGeocoderResult> {
        let promise = Promise<LocationGeocoderResult>()

        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale(locale)) { placemarks, error in
            if let error = error {
                promise.reject(withError: RuntimeError.error(withMessage: "GEOCODER_FAILED: \(error.localizedDescription)"))
                return
            }

            guard let placemark = placemarks?.first else {
                promise.reject(withError: RuntimeError.error(withMessage: "NO_RESULTS"))
                return
            }

            let result = LocationGeocoderResult(
                countryCode: placemark.isoCountryCode ?? "",
                country: placemark.country ?? "",
                locality: placemark.locality ?? "",
                administrativeArea: placemark.administrativeArea ?? "",
                subAdministrativeArea: placemark.subAdministrativeArea ?? "",
                subLocality: placemark.subLocality ?? ""
            )
            promise.resolve(withResult: result)
        }

        return promise
    }
}
