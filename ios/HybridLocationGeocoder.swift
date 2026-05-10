import Foundation
import CoreLocation
import NitroModules

class HybridLocationGeocoder: HybridLocationGeocoderSpec {

    private let timeoutSeconds: TimeInterval = 10

    private func preferredLocale(_ locale: String) -> Locale? {
        let normalized = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return nil
        }
        return Locale(identifier: normalized)
    }

    private func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180
    }

    func reverseGeocode(latitude: Double, longitude: Double, locale: String) throws -> Promise<LocationGeocoderResult> {
        let promise = Promise<LocationGeocoderResult>()

        guard isValidCoordinate(latitude: latitude, longitude: longitude) else {
            promise.reject(withError: RuntimeError.error(withMessage: "INVALID_COORDINATES"))
            return promise
        }

        let geocoder = CLGeocoder()
        var didComplete = false
        var timeoutWorkItem: DispatchWorkItem?

        func reject(_ message: String) {
            if didComplete {
                return
            }
            didComplete = true
            timeoutWorkItem?.cancel()
            promise.reject(withError: RuntimeError.error(withMessage: message))
        }

        func resolve(_ result: LocationGeocoderResult) {
            if didComplete {
                return
            }
            didComplete = true
            timeoutWorkItem?.cancel()
            promise.resolve(withResult: result)
        }

        timeoutWorkItem = DispatchWorkItem {
            reject("GEOCODER_TIMEOUT")
            geocoder.cancelGeocode()
        }
        if let timeoutWorkItem = timeoutWorkItem {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .milliseconds(Int(timeoutSeconds * 1000)),
                execute: timeoutWorkItem
            )
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale(locale)) { placemarks, error in
            if let error = error {
                reject("GEOCODER_FAILED: \(error.localizedDescription)")
                return
            }

            guard let placemark = placemarks?.first else {
                reject("NO_RESULTS")
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
            resolve(result)
        }

        return promise
    }
}
