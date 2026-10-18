import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class HourlyRainfallTests: XCTestCase {
    private var session: URLSession!
    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RainfallMockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = WeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        RainfallMockURLProtocol.handler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    func testDocumentedStringReadingsAndHourCrossingMidnight() throws {
        let report = try decode(Self.body(time: "2026-10-18T00:30:00+08:00"))
        XCTAssertEqual(report.readings.first?.id, "RF020")
        XCTAssertEqual(report.readings.first?.amount, 12)
        XCTAssertEqual(report.observationPeriod.duration, 3600)
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(report.observationPeriod.start, formatter.date(from: "2026-10-17T23:30:00+08:00"))
        XCTAssertEqual(report.observationPeriod.end, formatter.date(from: "2026-10-18T00:30:00+08:00"))
    }

    func testMaintenanceInValueOrUnitNeverBecomesZero() throws {
        let report = try decode(Self.body(stations: #"""
        [{"automaticWeatherStationID":"A","value":"M","unit":"mm"},
         {"automaticWeatherStationID":"B","value":"0","unit":"M"},
         {"automaticWeatherStationID":"C","value":" m ","unit":"mm"}]
        """#))
        XCTAssertTrue(report.readings.allSatisfy { $0.status == .maintenance && $0.amount == nil })
    }

    func testInvalidAndMissingMeasurementsRemainUnavailable() throws {
        let report = try decode(Self.body(stations: #"""
        [{"automaticWeatherStationID":"A","value":"-1","unit":"mm"},
         {"automaticWeatherStationID":"B","value":null,"unit":"mm"},
         {"automaticWeatherStationID":"C","unit":"mm"},
         {"automaticWeatherStationID":"D","value":true,"unit":"mm"},
         {"automaticWeatherStationID":"E","value":"1.5","unit":"mm"},
         {"automaticWeatherStationID":"F","value":"4","unit":"inch"},
         {"automaticWeatherStationID":"G","value":"bad","unit":"mm"},
         {"automaticWeatherStationID":"H","value":"5"}]
        """#))
        XCTAssertTrue(report.readings.allSatisfy { $0.status == .unavailable && $0.amount == nil })
    }

    func testNumericJSONAndGenuineZeroAreMeasurements() throws {
        let report = try decode(Self.body(stations: #"""
        [{"automaticWeatherStationID":"A","value":0,"unit":"mm"},
         {"automaticWeatherStationID":"B","value":7,"unit":"mm"}]
        """#))
        XCTAssertEqual(report.readings.map(\.amount), [0, 7])
        XCTAssertEqual(report.readings.first?.status, .measured(0))
    }

    func testRankingPlacesMeasuredAmountsBeforeUnavailableStationsWithStableTies() throws {
        let report = try decode(Self.body(stations: #"""
        [{"automaticWeatherStationID":"M","automaticWeatherStation":"Maintenance","value":"M","unit":"mm"},
         {"automaticWeatherStationID":"Z","automaticWeatherStation":"Zero","value":"0","unit":"mm"},
         {"automaticWeatherStationID":"B","automaticWeatherStation":"Beta","value":"8","unit":"mm"},
         {"automaticWeatherStationID":"A","automaticWeatherStation":"Alpha","value":"8","unit":"mm"},
         {"automaticWeatherStationID":"H","automaticWeatherStation":"Highest","value":"20","unit":"mm"}]
        """#))
        XCTAssertEqual(report.rankedStations(matching: "").map(\.id), ["H", "A", "B", "Z", "M"])
    }

    func testSearchMatchesBothLanguagesAndStationIDWithoutAnotherRequest() throws {
        let english = try decode(Self.body())
        for query in ["  sha tin  ", "沙田", "rf020"] {
            XCTAssertEqual(english.rankedStations(matching: query).map(\.id), ["RF020"])
        }
        let chinese = try decode(Self.body(stations: #"[{"automaticWeatherStationID":"RF020","automaticWeatherStation":"沙田","value":"4","unit":"mm"}]"#))
        XCTAssertEqual(chinese.rankedStations(matching: "Sha Tin").first?.amount, 4)
        XCTAssertTrue(chinese.rankedStations(matching: "unknown station").isEmpty)
    }

    func testApostropheSearchAndUnknownStationLiveNamesArePreserved() throws {
        let report = try decode(Self.body(stations: #"""
        [{"automaticWeatherStationID":"RF024","automaticWeatherStation":"King’s Park","value":"2","unit":"mm"},
         {"automaticWeatherStationID":"NEW99","automaticWeatherStation":"New Bay","value":"3","unit":"mm"}]
        """#))
        XCTAssertEqual(report.rankedStations(matching: "King's").first?.id, "RF024")
        let newStation = try XCTUnwrap(report.rankedStations(matching: "New Bay").first)
        XCTAssertEqual(newStation.name(lang: "tc"), "New Bay")
        XCTAssertEqual(newStation.amount, 3)
    }

    func testMissingNameUsesRainfallAliasesThenID() throws {
        let report = try decode(Self.body(stations: #"[{"automaticWeatherStationID":"RF020","value":"2","unit":"mm"},{"automaticWeatherStationID":"NEW99","value":"1","unit":"mm"}]"#))
        XCTAssertEqual(report.readings[0].name(lang: "en"), "Sha Tin")
        XCTAssertEqual(report.readings[0].name(lang: "tc"), "沙田")
        XCTAssertEqual(report.readings[1].name(lang: "en"), "NEW99")
    }

    func testEmptyCollectionIsValidAndNotInventedStationData() throws {
        let report = try decode(Self.body(stations: "[]"))
        XCTAssertTrue(report.readings.isEmpty)
        XCTAssertTrue(report.rankedStations(matching: "").isEmpty)
    }

    func testMalformedReportsAreRejected() {
        let bodies = ["{}", Self.body(time: "invalid time"),
                      #"{"obsTime":"2026-10-18T08:00:00+08:00"}"#,
                      #"{"obsTime":"2026-10-18T08:00:00+08:00","hourlyRainfall":null}"#,
                      Self.body(stations: #"[{"automaticWeatherStationID":"A"},{"automaticWeatherStationID":"A"}]"#),
                      Self.body(stations: #"[{"automaticWeatherStationID":"  "}]"#)]
        for body in bodies { XCTAssertThrowsError(try decode(body), body) }
    }

    func testFractionalObservationTimestampIsAccepted() throws {
        let report = try decode(Self.body(time: "2026-10-18T08:00:00.000+08:00"))
        XCTAssertEqual(report.observationTime, ISO8601DateFormatter().date(from: "2026-10-18T08:00:00+08:00"))
    }

    func testCatalogUsesSeparateRainfallIDsAndNames() {
        XCTAssertEqual(RainfallStationCatalog.names.count, 36)
        XCTAssertEqual(RainfallStationCatalog.names["RF020"]?.chinese, "沙田")
        XCTAssertEqual(RainfallStationCatalog.names["RF005"]?.english, "Tai Po Market")
        XCTAssertNil(RainfallStationCatalog.names["sha-tin"])
    }

    func testServiceUsesDedicatedEndpointLanguageAndReloadPolicy() {
        RainfallMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "data.weather.gov.hk")
            XCTAssertEqual(request.url?.path, "/weatherAPI/opendata/hourlyRainfall.php")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.httpMethod, "GET")
            let query = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(query.map(\.name), ["lang"])
            XCTAssertTrue(["en", "tc"].contains(query.first?.value ?? ""))
            return try Self.response(request, body: Self.body())
        }
        perform { service in
            for language in ["en", "tc"] {
                let report = try await service.hourlyRainfall(lang: language)
                XCTAssertEqual(report.readings.first?.amount, 12)
            }
        }
    }

    func testDedicatedEndpointPreservesInjectedBasePath() {
        let client = WeatherService(session: session, baseURL: "https://example.com/custom/weather.php")
        RainfallMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/custom/hourlyRainfall.php?lang=tc")
            return try Self.response(request, body: Self.body())
        }
        perform { _ in _ = try await client.hourlyRainfall(lang: "tc") }
    }

    func testHTTPAndDecodingFailuresAreReported() {
        RainfallMockURLProtocol.handler = { try Self.response($0, status: 503, body: "{}") }
        perform { service in
            do { _ = try await service.hourlyRainfall(lang: "en"); XCTFail("Expected HTTP failure") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .httpStatus(503)) }
            RainfallMockURLProtocol.handler = { try Self.response($0, body: "{}") }
            do { _ = try await service.hourlyRainfall(lang: "en"); XCTFail("Expected decoding failure") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
        }
    }

    func testInvalidBaseURLIsRejectedBeforeRainfallRequest() {
        let invalid = WeatherService(session: session, baseURL: "http://example.com/weather.php")
        RainfallMockURLProtocol.handler = { _ in XCTFail("Must not request an invalid URL"); throw URLError(.badURL) }
        perform { _ in
            do { _ = try await invalid.hourlyRainfall(lang: "en"); XCTFail("Expected invalid URL") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .invalidURL) }
        }
    }

    func testRepeatedRefreshPublishesFreshMeasurementsAndObservationTimes() {
        RainfallMockURLProtocol.handler = { try Self.response($0, body: Self.body()) }
        onMainActor { service in
            let model = HourlyRainfallViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.readings.first?.amount, 12)
            RainfallMockURLProtocol.handler = { request in
                XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
                return try Self.response(request, body: Self.body(time: "2026-10-18T09:00:00+08:00", stations: #"[{"automaticWeatherStationID":"RF020","value":"5","unit":"mm"}]"#))
            }
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.readings.first?.amount, 5)
            XCTAssertEqual(model.section.value?.observationTime, ISO8601DateFormatter().date(from: "2026-10-18T09:00:00+08:00"))
            XCTAssertNotNil(model.section.lastChecked)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testFailedRefreshRetainsPreviousReportAndRecovers() {
        RainfallMockURLProtocol.handler = { try Self.response($0, body: Self.body()) }
        onMainActor { service in
            let model = HourlyRainfallViewModel(service: service)
            await model.refresh(lang: "en")
            let checked = model.section.lastChecked
            let observed = model.section.value?.observationTime
            RainfallMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en")
            XCTAssertEqual(model.section.value?.readings.first?.amount, 12)
            XCTAssertEqual(model.section.value?.observationTime, observed)
            XCTAssertEqual(model.section.lastChecked, checked)
            XCTAssertNotNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
            RainfallMockURLProtocol.handler = { try Self.response($0, body: Self.body(stations: "[]")) }
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.errorMessage)
            XCTAssertEqual(model.section.value?.readings.count, 0)
        }
    }

    func testLanguageChangeFailureClearsPreviousLanguageReport() {
        RainfallMockURLProtocol.handler = { try Self.response($0, body: Self.body()) }
        onMainActor { service in
            let model = HourlyRainfallViewModel(service: service)
            await model.refresh(lang: "en")
            RainfallMockURLProtocol.handler = { request in
                XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "tc")
                throw URLError(.timedOut)
            }
            await model.refresh(lang: "tc")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.lastChecked)
            XCTAssertNotNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testInitialFailureNeverPublishesAnAllDryReport() {
        RainfallMockURLProtocol.handler = { try Self.response($0, body: "{}") }
        onMainActor { service in
            let model = HourlyRainfallViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.lastChecked)
            XCTAssertNotNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    func testCancellationDoesNotInventReadingsOrShowAnError() {
        RainfallMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        onMainActor { service in
            let model = HourlyRainfallViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertNil(model.section.value)
            XCTAssertNil(model.section.errorMessage)
            XCTAssertFalse(model.section.isLoading)
        }
    }

    private func decode(_ body: String) throws -> HourlyRainfallReport {
        try JSONDecoder().decode(HourlyRainfallReport.self, from: Data(body.utf8))
    }

    private static func body(time: String = "2026-10-18T08:00:00+08:00",
                             stations: String = #"[{"automaticWeatherStationID":"RF020","automaticWeatherStation":"Sha Tin","value":"12","unit":"mm"}]"#) -> String {
        "{\"obsTime\":\"\(time)\",\"hourlyRainfall\":\(stations)}"
    }

    private static func response(_ request: URLRequest, status: Int = 200, body: String) throws -> (HTTPURLResponse, Data) {
        (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)), Data(body.utf8))
    }

    private func perform(_ operation: @escaping (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Rainfall request completes")
        let client = service!
        Task {
            do { try await operation(client) }
            catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    private func onMainActor(_ operation: @escaping @MainActor (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Rainfall view model completes")
        let client = service!
        Task { @MainActor in
            do { try await operation(client) }
            catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}

private final class RainfallMockURLProtocol: URLProtocol {
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
