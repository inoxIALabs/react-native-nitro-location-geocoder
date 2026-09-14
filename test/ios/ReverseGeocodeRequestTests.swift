import Foundation
import Testing
@testable import LocationGeocoderCore

@MainActor
private final class ControlledGeocoder: LocationGeocoding {
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var locale: Locale?
    private(set) var cancellationCount = 0
    var responseOnCancel: GeocodingResponse?
    var completion: (@MainActor @Sendable (GeocodingResponse) -> Void)?

    func reverseGeocode(
        latitude: Double,
        longitude: Double,
        preferredLocale: Locale?,
        completion: @escaping @MainActor @Sendable (GeocodingResponse) -> Void
    ) {
        self.latitude = latitude
        self.longitude = longitude
        locale = preferredLocale
        self.completion = completion
    }

    func cancel() {
        cancellationCount += 1
        if let responseOnCancel {
            completion?(responseOnCancel)
        }
    }
}

@MainActor
private final class ControlledTimeout: GeocodingTimeout {
    var action: GeocodingTimeoutAction?
    private(set) var cancellationCount = 0

    func cancel() {
        cancellationCount += 1
        action = nil
    }

    func fire() {
        action?()
    }
}

@MainActor
private final class ControlledClock {
    let timeout = ControlledTimeout()
    private(set) var delay: TimeInterval?

    func schedule(after delay: TimeInterval, action: @escaping GeocodingTimeoutAction) -> any GeocodingTimeout {
        self.delay = delay
        timeout.action = action
        return timeout
    }
}

@MainActor
private final class Responses {
    var values: [GeocodingResponse] = []
}

@MainActor
private final class RequestFixture {
    let geocoder: ControlledGeocoder
    let clock: ControlledClock
    let responses: Responses
    let request: ReverseGeocodeRequest

    init(locale: String = "es-PE") {
        let geocoder = ControlledGeocoder()
        let clock = ControlledClock()
        let responses = Responses()
        self.geocoder = geocoder
        self.clock = clock
        self.responses = responses
        request = ReverseGeocodeRequest(geocoder: geocoder) { delay, action in
            clock.schedule(after: delay, action: action)
        }
        request.start(latitude: -12.0464, longitude: -77.0428, locale: locale) { response in
            responses.values.append(response)
        }
    }
}

@MainActor
private final class CompletionCapture {
    var response: GeocodingResponse?
}

private let lima = GeocodedLocation(
    countryCode: "PE",
    country: "Peru",
    locality: "Lima",
    administrativeArea: "Lima",
    subAdministrativeArea: "Lima",
    subLocality: ""
)

@MainActor
struct ReverseGeocodeRequestTests {
    @Test
    func successPreservesInputsAndResultAndCancelsTimeout() {
        let fixture = RequestFixture(locale: "  es-PE\n")

        #expect(fixture.geocoder.latitude == -12.0464)
        #expect(fixture.geocoder.longitude == -77.0428)
        #expect(fixture.geocoder.locale == Locale(identifier: "es-PE"))
        #expect(fixture.clock.delay == 10)

        fixture.geocoder.completion?(.success(lima))

        #expect(fixture.responses.values == [.success(lima)])
        #expect(fixture.clock.timeout.cancellationCount == 1)
        #expect(fixture.geocoder.cancellationCount == 0)
    }

    @Test(arguments: ["", " \t\n"])
    func blankLocaleUsesSystemDefault(locale: String) {
        let fixture = RequestFixture(locale: locale)
        #expect(fixture.geocoder.locale == nil)
        fixture.geocoder.completion?(.success(lima))
    }

    @Test(arguments: [GeocodingError.noResults, .failed("network unavailable")])
    func failuresSettleOnceAndCancelTimeout(error: GeocodingError) throws {
        let fixture = RequestFixture()
        let lateTimeout = try #require(fixture.clock.timeout.action)
        let callback = try #require(fixture.geocoder.completion)

        callback(.failure(error))
        callback(.success(lima))
        lateTimeout()

        #expect(fixture.responses.values == [.failure(error)])
        #expect(fixture.clock.timeout.cancellationCount == 1)
        #expect(fixture.geocoder.cancellationCount == 0)
    }

    @Test
    func timeoutWinsOverReentrantCancellationAndLateCallbacks() throws {
        let fixture = RequestFixture()
        fixture.geocoder.responseOnCancel = .failure(.failed("cancelled by platform"))
        let lateTimeout = try #require(fixture.clock.timeout.action)
        let callback = try #require(fixture.geocoder.completion)

        fixture.clock.timeout.fire()
        callback(.success(lima))
        callback(.failure(.noResults))
        lateTimeout()

        #expect(fixture.responses.values == [.failure(.timedOut)])
        #expect(fixture.geocoder.cancellationCount == 1)
        #expect(fixture.clock.timeout.cancellationCount == 1)
    }

    @Test
    func successIgnoresDuplicateResponsesAndAlreadyQueuedTimeout() throws {
        let fixture = RequestFixture()
        let callback = try #require(fixture.geocoder.completion)
        let lateTimeout = try #require(fixture.clock.timeout.action)

        callback(.success(lima))
        callback(.success(lima))
        callback(.failure(.failed("late error")))
        lateTimeout()

        #expect(fixture.responses.values == [.success(lima)])
        #expect(fixture.geocoder.cancellationCount == 0)
        #expect(fixture.clock.timeout.cancellationCount == 1)
    }

    @Test
    func requestsHaveIndependentGeocodersAndDeadlines() {
        let first = RequestFixture()
        let second = RequestFixture()

        first.clock.timeout.fire()
        second.geocoder.completion?(.success(lima))

        #expect(first.responses.values == [.failure(.timedOut)])
        #expect(second.responses.values == [.success(lima)])
        #expect(first.geocoder.cancellationCount == 1)
        #expect(second.geocoder.cancellationCount == 0)
    }

    @Test
    func concurrentResponseAndTimeoutDeliverySettlesExactlyOnce() async throws {
        let fixture = RequestFixture()
        let callback = try #require(fixture.geocoder.completion)
        let timeout = try #require(fixture.clock.timeout.action)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<64 {
                group.addTask {
                    if index.isMultiple(of: 2) {
                        await callback(.success(lima))
                    } else {
                        await timeout()
                    }
                }
            }
        }

        #expect(fixture.responses.values.count == 1)
        #expect(fixture.clock.timeout.cancellationCount == 1)
        let timedOut = fixture.responses.values.first == .failure(.timedOut)
        #expect(fixture.geocoder.cancellationCount == (timedOut ? 1 : 0))
    }

    @Test(arguments: [
        GeocodingResponse.success(lima),
        .failure(.noResults),
        .failure(.failed("network unavailable")),
        .failure(.timedOut),
    ])
    func settlementReleasesRequestGeocoderAndCompletionCapture(response: GeocodingResponse) throws {
        let clock = ControlledClock()
        var geocoder: ControlledGeocoder? = ControlledGeocoder()
        var capture: CompletionCapture? = CompletionCapture()
        weak var weakGeocoder = geocoder
        weak var weakCapture = capture
        var request: ReverseGeocodeRequest? = ReverseGeocodeRequest(geocoder: try #require(geocoder)) { delay, action in
            clock.schedule(after: delay, action: action)
        }
        weak var weakRequest = request
        let responses = Responses()
        request?.start(latitude: -12.0464, longitude: -77.0428, locale: "es-PE") { [capture] response in
            capture?.response = response
            responses.values.append(response)
        }
        let callback = try #require(geocoder?.completion)

        geocoder = nil
        capture = nil
        request = nil
        #expect(weakRequest != nil)
        #expect(weakGeocoder != nil)
        #expect(weakCapture != nil)

        if response == .failure(.timedOut) {
            clock.timeout.fire()
        } else {
            callback(response)
        }

        #expect(responses.values == [response])
        #expect(weakRequest == nil)
        #expect(weakGeocoder == nil)
        #expect(weakCapture == nil)
        callback(.failure(.failed("callback retained by platform")))
        #expect(responses.values.count == 1)
    }

    @Test
    func nativeErrorMessagesRemainStable() {
        #expect(GeocodingError.timedOut.message == "GEOCODER_TIMEOUT")
        #expect(GeocodingError.noResults.message == "NO_RESULTS")
        #expect(GeocodingError.failed("network unavailable").message == "GEOCODER_FAILED: network unavailable")
    }
}
