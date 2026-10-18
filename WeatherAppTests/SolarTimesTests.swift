import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class SolarTimesTests: XCTestCase {
    private var session: URLSession!
    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SolarMockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = WeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        SolarMockURLProtocol.handler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    func testHKOResponseUsesHongKongEventDatesAndDaylightDuration() throws {
        let day = try XCTUnwrap(decode(Self.body()).days.first)
        XCTAssertEqual(day.date, Self.date("2026-10-18T00:00:00+08:00"))
        XCTAssertEqual(day.sunrise, Self.date("2026-10-18T06:21:00+08:00"))
        XCTAssertEqual(day.sunset, Self.date("2026-10-18T17:56:00+08:00"))
        XCTAssertEqual(day.daylightDuration, 11 * 3600 + 35 * 60)
    }

    func testReorderedColumnsAndExtraMetadataDoNotSwapEvents() throws {
        let day = try XCTUnwrap(decode(#"{"fields":["SET","extra","YYYY-MM-DD","RISE"],"data":[["18:00","ignored","2026-10-18","06:00"]]}"#).days.first)
        XCTAssertEqual(day.sunrise, Self.date("2026-10-18T06:00:00+08:00"))
        XCTAssertEqual(day.sunset, Self.date("2026-10-18T18:00:00+08:00"))
    }

    func testMissingEventsRemainUnavailableWithoutInventingMidnight() throws {
        let day = try XCTUnwrap(decode(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-18","",null]]}"#).days.first)
        XCTAssertNil(day.sunrise)
        XCTAssertNil(day.sunset)
        XCTAssertNil(day.daylightDuration)
        XCTAssertNil(day.daylightProgress(at: Self.date("2026-10-18T12:00:00+08:00")))
    }

    func testMalformedSchemaDatesRowsAndEventOrderAreRejected() {
        let bodies = ["{}", #"{"fields":[],"data":[]}"#,
                      #"{"fields":["YYYY-MM-DD","RISE","SET","RISE"],"data":[]}"#,
                      #"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-18","06:00"]]}"#,
                      Self.body(day: "2026-02-30"), Self.body(day: "2026-13-01"),
                      Self.body(day: "not-a-date"), Self.body(day: "2026-1-1"),
                      Self.body(rise: "24:00"), Self.body(rise: "06:60"), Self.body(rise: "six"),
                      Self.body(rise: "6:21"), Self.body(rise: "18:00", set: "06:00"),
                      Self.body(rise: "06:00", set: "06:00")]
        for body in bodies { XCTAssertThrowsError(try decode(body), body) }
    }

    func testDuplicateDatesAreRejectedAndEmptyTableIsNotFakeData() throws {
        XCTAssertThrowsError(try decode(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-18","06:00","18:00"],["2026-10-18","06:00","18:00"]]}"#))
        XCTAssertTrue(try decode(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[]}"#).days.isEmpty)
    }

    func testLeapDayIsAcceptedAndInvalidNonLeapDayRejected() throws {
        XCTAssertEqual(try decode(Self.body(day: "2028-02-29")).days.count, 1)
        XCTAssertThrowsError(try decode(Self.body(day: "2027-02-29")))
    }

    func testDaylightProgressClampsAndIsUnavailableForAnotherHongKongDate() throws {
        let day = try XCTUnwrap(decode(Self.body(rise: "06:00", set: "18:00")).days.first)
        XCTAssertEqual(day.daylightProgress(at: Self.date("2026-10-18T05:00:00+08:00")), 0)
        XCTAssertEqual(day.daylightProgress(at: Self.date("2026-10-18T12:00:00+08:00")), 0.5)
        XCTAssertEqual(day.daylightProgress(at: Self.date("2026-10-18T20:00:00+08:00")), 1)
        XCTAssertNil(day.daylightProgress(at: Self.date("2026-10-19T00:00:00+08:00")))
    }

    func testNextEventBeforeSunriseAtSunriseAndAtSunset() throws {
        let snapshot = try snapshot()
        let before = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-18T06:20:00+08:00")))
        XCTAssertEqual(before.kind, .sunrise)
        XCTAssertEqual(before.time, snapshot.today.sunrise)
        let daytime = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-18T06:21:00+08:00")))
        XCTAssertEqual(daytime.kind, .sunset)
        XCTAssertEqual(daytime.time, snapshot.today.sunset)
        let after = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-18T17:56:00+08:00")))
        XCTAssertEqual(after.kind, .sunrise)
        XCTAssertEqual(after.time, Self.date("2026-10-19T06:22:00+08:00"))
    }

    func testMissingTomorrowOrWrongDateNeverInventsNextSunrise() throws {
        let snapshot = try snapshot()
        let night = Self.date("2026-10-18T22:00:00+08:00")
        XCTAssertNil(SolarTimesSnapshot(today: snapshot.today, tomorrow: nil).nextEvent(at: night))
        XCTAssertNil(SolarTimesSnapshot(today: snapshot.today, tomorrow: snapshot.today).nextEvent(at: night))
        XCTAssertNil(snapshot.nextEvent(at: Self.date("2026-10-19T00:00:00+08:00")))
    }

    func testHongKongFormattingUsesEventTimeRatherThanDeviceTimeZone() {
        let date = Self.date("2026-10-17T22:21:00Z")
        for locale in [Locale(identifier: "en_HK"), Locale(identifier: "zh_Hant_HK")] {
            XCTAssertEqual(SolarTimesFormatting.time(date, locale: locale), "06:21")
            let duration = SolarTimesFormatting.duration(11 * 3600 + 35 * 60, locale: locale)
            XCTAssertFalse(duration.isEmpty)
            XCTAssertNotEqual(duration, "—")
        }
    }

    func testServiceRequestsSRSInJSONUsingHongKongDateAndNoCachePolicy() {
        SolarMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/weatherAPI/opendata/opendata.php")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) }),
                           ["dataType": "SRS", "year": "2026", "month": "10", "day": "18", "rformat": "json"])
            return try Self.response(request, body: Self.body())
        }
        perform { service in
            _ = try await service.solarTimes(on: Self.date("2026-10-17T18:00:00Z"))
        }
    }

    func testSolarEndpointPreservesInjectedBasePath() {
        let client = WeatherService(session: session, baseURL: "https://example.com/custom/weather.php")
        SolarMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "example.com")
            XCTAssertEqual(request.url?.path, "/custom/opendata.php")
            return try Self.response(request, body: Self.body())
        }
        perform { _ in _ = try await client.solarTimes(on: Self.date("2026-10-18T12:00:00+08:00")) }
    }

    func testWrongDateAndEmptyResponseAreServiceErrors() {
        perform { service in
            for body in [Self.body(day: "2026-10-17"), #"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[]}"#] {
                SolarMockURLProtocol.handler = { try Self.response($0, body: body) }
                do { _ = try await service.solarTimes(on: Self.date("2026-10-18T12:00:00+08:00")); XCTFail("Expected date validation failure") }
                catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
            }
        }
    }

    func testSolarHTTPFailureUsesSharedServiceError() {
        SolarMockURLProtocol.handler = { try Self.response($0, body: "{}", status: 503) }
        perform { service in
            do { _ = try await service.solarTimes(on: Self.date("2026-10-18T12:00:00+08:00")); XCTFail("Expected HTTP error") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .httpStatus(503)) }
        }
    }

    func testRepeatedRefreshFetchesTodayAndTomorrowAgain() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-10-18T12:00:00+08:00") })
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.today.sunrise, Self.date("2026-10-18T06:21:00+08:00"))
            XCTAssertEqual(model.section.value?.tomorrow?.sunrise, Self.date("2026-10-19T06:21:00+08:00"))
            SolarMockURLProtocol.handler = { request in
                let parts = try Self.query(request)
                return try Self.response(request, body: Self.body(day: "\(parts["year"]!)-\(parts["month"]!)-\(parts["day"]!)", rise: "06:30"))
            }
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.today.sunrise, Self.date("2026-10-18T06:30:00+08:00"))
            XCTAssertEqual(model.section.value?.tomorrow?.sunrise, Self.date("2026-10-19T06:30:00+08:00"))
            XCTAssertNotNil(model.section.lastChecked)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testTomorrowFailurePreservesTodaysEventsWithoutInventingNextEvent() {
        SolarMockURLProtocol.handler = { request in
            if try Self.query(request)["day"] == "19" { throw URLError(.timedOut) }
            return try Self.dailyResponse(request)
        }
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-10-18T22:00:00+08:00") })
            await model.refresh(lang: "en")
            XCTAssertNotNil(model.section.value?.today.sunrise)
            XCTAssertNil(model.section.value?.tomorrow)
            XCTAssertNil(model.section.value?.nextEvent(at: Self.date("2026-10-18T22:00:00+08:00")))
            XCTAssertNil(model.section.errorMessage)
        }
    }

    func testRefreshFailureRetainsDatedSnapshotAndRecovers() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-10-18T12:00:00+08:00") })
            await model.refresh(lang: "en")
            let checked = model.section.lastChecked
            SolarMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en")
            XCTAssertNotNil(model.section.value)
            XCTAssertEqual(model.section.lastChecked, checked)
            XCTAssertNotNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
            SolarMockURLProtocol.handler = Self.dailyResponse
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.errorMessage)
        }
    }

    func testHongKongDateRolloverClearsOldTimesOnFailedRefresh() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            var now = Self.date("2026-10-18T23:59:00+08:00")
            let model = SolarTimesViewModel(service: service, now: { now })
            await model.refresh(lang: "en")
            now = Self.date("2026-10-19T00:00:00+08:00")
            SolarMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.lastChecked)
            XCTAssertNotNil(model.section.errorMessage)
        }
    }

    func testYearBoundaryRequestsJanuaryFirstAsTomorrow() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-12-31T22:00:00+08:00") })
            await model.refresh(lang: "tc")
            XCTAssertEqual(model.section.value?.today.date, Self.date("2026-12-31T00:00:00+08:00"))
            XCTAssertEqual(model.section.value?.tomorrow?.date, Self.date("2027-01-01T00:00:00+08:00"))
            XCTAssertEqual(model.section.value?.nextEvent(at: Self.date("2026-12-31T22:00:00+08:00"))?.time,
                           Self.date("2027-01-01T06:21:00+08:00"))
        }
    }

    func testInFlightRequestCrossingMidnightReloadsTheNewHongKongDate() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            var clockReads = 0
            let model = SolarTimesViewModel(service: service, now: {
                clockReads += 1
                return Self.date(clockReads == 1 ? "2026-10-18T23:59:59+08:00" : "2026-10-19T00:00:01+08:00")
            })
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.today.date, Self.date("2026-10-19T00:00:00+08:00"))
            XCTAssertEqual(model.section.value?.tomorrow?.date, Self.date("2026-10-20T00:00:00+08:00"))
            XCTAssertNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testLanguageChangeFailureClearsPreviousSection() {
        SolarMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-10-18T12:00:00+08:00") })
            await model.refresh(lang: "en")
            SolarMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
            await model.refresh(lang: "tc")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.lastChecked)
            XCTAssertNotNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testInitialFailureAndCancellationDoNotCreateSolarEvents() {
        onMainActor { service in
            let model = SolarTimesViewModel(service: service, now: { Self.date("2026-10-18T12:00:00+08:00") })
            SolarMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
            SolarMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.value)
            XCTAssertNotNil(model.section.errorMessage)
        }
    }

    private func decode(_ body: String) throws -> SolarTimesResponse {
        try JSONDecoder().decode(SolarTimesResponse.self, from: Data(body.utf8))
    }

    private func snapshot() throws -> SolarTimesSnapshot {
        SolarTimesSnapshot(today: try XCTUnwrap(decode(Self.body()).days.first),
                           tomorrow: try XCTUnwrap(decode(Self.body(day: "2026-10-19", rise: "06:22")).days.first))
    }

    private static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private static func body(day: String = "2026-10-18", rise: String = "06:21", set: String = "17:56") -> String {
        "{\"fields\":[\"YYYY-MM-DD\",\"RISE\",\"TRAN.\",\"SET\"],\"data\":[[\"\(day)\",\"\(rise)\",\"12:09\",\"\(set)\"]]}"
    }
    private static func query(_ request: URLRequest) throws -> [String: String] {
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
    }
    private static func dailyResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let parts = try query(request)
        let day = String(format: "%04d-%02d-%02d", Int(parts["year"]!)!, Int(parts["month"]!)!, Int(parts["day"]!)!)
        return try response(request, body: body(day: day))
    }
    private static func response(_ request: URLRequest, body: String, status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)), Data(body.utf8))
    }
    private func perform(_ operation: @escaping (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Solar request completes")
        let client = service!
        Task {
            do { try await operation(client) } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
    private func onMainActor(_ operation: @escaping @MainActor (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Solar view model completes")
        let client = service!
        Task { @MainActor in
            do { try await operation(client) } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}

private final class SolarMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { lock.lock(); defer { lock.unlock() }; return storedHandler }
        set { lock.lock(); defer { lock.unlock() }; storedHandler = newValue }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.1)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
