import Foundation

struct GeocodedLocation: Sendable, Equatable {
    let countryCode: String
    let country: String
    let locality: String
    let administrativeArea: String
    let subAdministrativeArea: String
    let subLocality: String
}

enum GeocodingError: Error, Equatable {
    case timedOut
    case noResults
    case failed(String)

    var message: String {
        switch self {
        case .timedOut:
            return "GEOCODER_TIMEOUT"
        case .noResults:
            return "NO_RESULTS"
        case .failed(let description):
            return "GEOCODER_FAILED: \(description)"
        }
    }
}

typealias GeocodingResponse = Result<GeocodedLocation, GeocodingError>

@MainActor
protocol LocationGeocoding: AnyObject {
    func reverseGeocode(
        latitude: Double,
        longitude: Double,
        preferredLocale: Locale?,
        completion: @escaping @MainActor @Sendable (GeocodingResponse) -> Void
    )
    func cancel()
}

@MainActor
protocol GeocodingTimeout: AnyObject {
    func cancel()
}

typealias GeocodingTimeoutAction = @MainActor @Sendable () -> Void
typealias GeocodingTimeoutScheduler = @MainActor (
    TimeInterval, @escaping GeocodingTimeoutAction
) -> any GeocodingTimeout

@MainActor
private final class TaskGeocodingTimeout: GeocodingTimeout {
    private var task: Task<Void, Never>?

    init(after seconds: TimeInterval, action: @escaping GeocodingTimeoutAction) {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1_000_000_000)
        task = Task { @MainActor in
            do {
                let now = DispatchTime.now().uptimeNanoseconds
                if now < deadline {
                    try await Task.sleep(nanoseconds: deadline - now)
                }
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@MainActor
private func scheduleGeocodingTimeout(
    after seconds: TimeInterval,
    action: @escaping GeocodingTimeoutAction
) -> any GeocodingTimeout {
    TaskGeocodingTimeout(after: seconds, action: action)
}

@MainActor
final class ReverseGeocodeRequest {
    private var geocoder: (any LocationGeocoding)?
    private var timeout: (any GeocodingTimeout)?
    private var completion: (@MainActor (GeocodingResponse) -> Void)?
    private let scheduleTimeout: GeocodingTimeoutScheduler
    private var started = false

    init(
        geocoder: any LocationGeocoding,
        scheduleTimeout: @escaping GeocodingTimeoutScheduler = scheduleGeocodingTimeout
    ) {
        self.geocoder = geocoder
        self.scheduleTimeout = scheduleTimeout
    }

    func start(
        latitude: Double,
        longitude: Double,
        locale: String,
        completion: @escaping @MainActor (GeocodingResponse) -> Void
    ) {
        guard !started, let geocoder else { return }
        started = true
        self.completion = completion

        // The timeout keeps the request alive even if the platform never calls
        // back. Settlement cancels it and drops every retained native resource.
        timeout = scheduleTimeout(10) { [self] in
            finish(.failure(.timedOut), cancelGeocoder: true)
        }

        let normalizedLocale = locale.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredLocale = normalizedLocale.isEmpty ? nil : Locale(identifier: normalizedLocale)
        geocoder.reverseGeocode(
            latitude: latitude,
            longitude: longitude,
            preferredLocale: preferredLocale
        ) { [weak self] response in
            self?.finish(response)
        }
    }

    private func finish(_ response: GeocodingResponse, cancelGeocoder: Bool = false) {
        guard let completion else { return }
        self.completion = nil

        let geocoder = geocoder
        self.geocoder = nil
        timeout?.cancel()
        timeout = nil

        // Clear settlement state before cancellation, which may cause the
        // platform to deliver another callback immediately.
        if cancelGeocoder {
            geocoder?.cancel()
        }
        completion(response)
    }
}
