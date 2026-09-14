import Foundation
import NitroModules

final class HybridLocationGeocoder: HybridLocationGeocoderSpec {
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

        // Nitro's entry point is nonisolated. Only its Sendable promise and the
        // input values cross into the actor that owns the native request.
        Task { @MainActor in
            let request = ReverseGeocodeRequest(geocoder: SystemLocationGeocoder())
            request.start(latitude: latitude, longitude: longitude, locale: locale) { response in
                switch response {
                case .success(let location):
                    // The generated result is backed by C++; construct it here
                    // instead of transferring it between isolation domains.
                    promise.resolve(withResult: LocationGeocoderResult(
                        countryCode: location.countryCode,
                        country: location.country,
                        locality: location.locality,
                        administrativeArea: location.administrativeArea,
                        subAdministrativeArea: location.subAdministrativeArea,
                        subLocality: location.subLocality
                    ))
                case .failure(let error):
                    promise.reject(withError: RuntimeError.error(withMessage: error.message))
                }
            }
        }

        return promise
    }
}
