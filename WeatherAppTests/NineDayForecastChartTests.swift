import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class NineDayForecastChartTests: XCTestCase {
    private var session: URLSession!
    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ForecastChartMockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = WeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        ForecastChartMockURLProtocol.handler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    func testForecastDatesAreSortedWithoutChangingTheSourceReport() {
        let source = NineDayWeatherForecast(weatherForecast: [day("20261020"), day("20261018"), day("20261019")])
        let data = NineDayForecastChartData(forecast: source)
        XCTAssertEqual(data.days.map(\.id), ["20261018", "20261019", "20261020"])
        XCTAssertEqual(source.weatherForecast?.map(\.forecastDate), ["20261020", "20261018", "20261019"])
        XCTAssertEqual(data.omittedDateCount, 0)
    }

    func testDatesUseGregorianHongKongMidnightAcrossYearAndLeapBoundaries() throws {
        let data = model([day("20270101"), day("20261231"), day("20280229")])
        XCTAssertEqual(data.days.first?.date, iso("2026-12-31T00:00:00+08:00"))
        XCTAssertEqual(data.days[1].date, iso("2027-01-01T00:00:00+08:00"))
        XCTAssertEqual(data.days.last?.date, iso("2028-02-29T00:00:00+08:00"))
    }

    func testInvalidMissingAndNonLeapDatesAreOmittedFromChartOnly() {
        let records = [day("20260230"), day("20270229"), day("20261301"), day("20260010"),
                       day("2026-10-18"), day("2026101"), day("bad date"), WeatherForecast(), day("20261018")]
        let data = model(records)
        XCTAssertEqual(data.days.map(\.id), ["20261018"])
        XCTAssertEqual(data.omittedDateCount, records.count - 1)
        XCTAssertTrue(data.hasUnavailableValues)
        XCTAssertEqual(records.count, 9)
    }

    func testDuplicateDatesDoNotSelectAnArbitraryConflictingRecord() {
        let data = model([day("20261018", low: 20), day("20261018", low: 23), day("20261019")])
        XCTAssertEqual(data.days.map(\.id), ["20261019"])
        XCTAssertEqual(data.omittedDateCount, 2)
    }

    func testActualZeroAndNegativeTemperaturesArePlotted() {
        let data = model([day("20261018", low: -2, high: 0)])
        XCTAssertEqual(data.points(unit: .celsius).map(\.value), [-2, 0])
        XCTAssertFalse(data.hasUnavailableValues)
    }

    func testMissingTemperatureDoesNotBecomeZeroOrHideAvailableSeries() {
        let data = model([day("20261018", low: nil, high: 28)])
        let points = data.points(unit: .celsius)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.kind, .high)
        XCTAssertEqual(points.first?.value, 28)
        XCTAssertTrue(data.hasUnavailableValues)
    }

    func testUnsupportedOrMissingUnitsAreNotInterpretedAsCelsius() {
        var first = day("20261018")
        first.forecastMintemp?.unit = "F"
        first.forecastMaxtemp?.unit = nil
        let data = model([first, day("20261019")])
        XCTAssertEqual(data.points(unit: .fahrenheit).map(\.dayID), ["20261019", "20261019"])
        XCTAssertTrue(data.hasUnavailableValues)
    }

    func testInvertedHighLowRangeIsNotPlottedButForecastTextIsPreserved() throws {
        var source = day("20261018", low: 30, high: 20)
        source.forecastWeather = "Official forecast text"
        let data = model([source])
        XCTAssertTrue(data.points(unit: .celsius).isEmpty)
        XCTAssertNil(data.days.first?.lowCelsius)
        XCTAssertNil(data.days.first?.highCelsius)
        XCTAssertEqual(data.days.first?.forecast.forecastWeather, source.forecastWeather)
        XCTAssertEqual(data.days.first?.forecast.forecastMintemp?.value, 30)
    }

    func testCelsiusAndFahrenheitUseNumericConversionWithoutMutatingOfficialData() throws {
        var source = day("20261018", low: 20, high: 26)
        source.forecastWeather = "Around 26 degrees Celsius"
        let data = model([source])
        let celsius = data.points(unit: .celsius)
        let fahrenheit = data.points(unit: .fahrenheit)
        XCTAssertEqual(celsius.map(\.value), [20, 26])
        XCTAssertEqual(fahrenheit[0].value, 68, accuracy: 0.0001)
        XCTAssertEqual(fahrenheit[1].value, 78.8, accuracy: 0.0001)
        XCTAssertEqual(celsius.map(\.id), fahrenheit.map(\.id))
        XCTAssertEqual(data.days.first?.forecast.forecastWeather, source.forecastWeather)
        XCTAssertEqual(data.days.first?.forecast.forecastMaxtemp?.value, 26)
    }

    func testMissingValueBreaksOnlyItsOwnTemperatureLine() throws {
        let data = model([day("20261018"), day("20261019", low: nil), day("20261020")])
        let low = data.points(unit: .celsius).filter { $0.kind == .low }
        let high = data.points(unit: .celsius).filter { $0.kind == .high }
        XCTAssertEqual(low.count, 2)
        XCTAssertNotEqual(low[0].seriesID, low[1].seriesID)
        XCTAssertEqual(Set(high.map(\.seriesID)).count, 1)
    }

    func testMissingCalendarDayBreaksBothTemperatureLines() {
        let points = model([day("20261018"), day("20261020")]).points(unit: .celsius)
        for kind in NineDayForecastChartData.TemperatureKind.allCases {
            XCTAssertEqual(Set(points.filter { $0.kind == kind }.map(\.seriesID)).count, 2)
        }
    }

    func testConsecutiveDatesAcrossMonthsAndYearsRemainConnected() {
        let points = model([day("20261231"), day("20270101"), day("20270102")]).points(unit: .celsius)
        for kind in NineDayForecastChartData.TemperatureKind.allCases {
            XCTAssertEqual(Set(points.filter { $0.kind == kind }.map(\.seriesID)).count, 1)
        }
    }

    func testDayIdentityAndSelectionSurviveReorderingAndNewReadings() throws {
        let original = model([day("20261018"), day("20261019")])
        let selectedID = try XCTUnwrap(original.selectedDay(id: "20261019")).id
        let refreshed = model([day("20261019", high: 31), day("20261018", high: 29)])
        XCTAssertEqual(refreshed.selectedDay(id: selectedID)?.id, selectedID)
        XCTAssertEqual(refreshed.selectedDay(id: selectedID)?.highCelsius, 31)
    }

    func testSelectionFallsBackToFirstAvailableDayWhenOldDayDisappears() {
        let data = model([day("20261020"), day("20261019")])
        XCTAssertEqual(data.selectedDay(id: "20261018")?.id, "20261019")
        XCTAssertEqual(data.selectedDay(id: nil)?.id, "20261019")
        XCTAssertNil(model([]).selectedDay(id: "20261018"))
    }

    func testTapDateSelectsNearestActualForecastDate() {
        let data = model([day("20261018"), day("20261019"), day("20261020")])
        XCTAssertEqual(data.nearestDay(to: iso("2026-10-18T23:00:00+08:00"))?.id, "20261019")
        XCTAssertEqual(data.nearestDay(to: iso("2026-10-17T20:00:00+08:00"))?.id, "20261018")
        XCTAssertEqual(data.nearestDay(to: iso("2026-10-21T00:00:00+08:00"))?.id, "20261020")
        XCTAssertNil(model([]).nearestDay(to: .now))
    }

    func testEmptyAndAllMissingReportsDoNotInventTemperaturePoints() {
        XCTAssertTrue(NineDayForecastChartData(forecast: NineDayWeatherForecast()).points(unit: .celsius).isEmpty)
        let data = model([day("20261018", low: nil, high: nil)])
        XCTAssertTrue(data.points(unit: .fahrenheit).isEmpty)
        XCTAssertNotNil(data.selectedDay(id: nil))
    }

    func testSelectedDayPreservesHumidityWindWeatherAndRainCategory() {
        var source = day("20261018")
        source.forecastWeather = "Sunny periods"
        source.forecastWind = "Easterly winds"
        source.forecastMaxrh = ForecastValueWithUnit(value: 85, unit: "percent")
        source.forecastMinrh = ForecastValueWithUnit(value: 65, unit: "percent")
        source.PSR = "Medium High"
        let selected = model([source]).selectedDay(id: nil)?.forecast
        XCTAssertEqual(selected?.forecastWeather, source.forecastWeather)
        XCTAssertEqual(selected?.forecastWind, source.forecastWind)
        XCTAssertEqual(selected?.forecastMaxrh?.value, 85)
        XCTAssertEqual(selected?.forecastMinrh?.value, 65)
        XCTAssertEqual(selected?.PSR, "Medium High")
    }

    func testRepeatedForecastLoadsRequestFreshValuesForTheChart() {
        ForecastChartMockURLProtocol.handler = { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.url?.path, "/weatherAPI/opendata/weather.php")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "dataType" })?.value, "fnd")
            XCTAssertEqual(query?.first(where: { $0.name == "lang" })?.value, "en")
            return try Self.response(request, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261018", high: 28)]))
        }
        onMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadNineDayForecast(lang: "en")
            XCTAssertEqual(NineDayForecastChartData(forecast: model.nineDayWeatherForecast).days.first?.highCelsius, 28)
            ForecastChartMockURLProtocol.handler = { request in
                XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
                return try Self.response(request, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261018", high: 31)]))
            }
            await model.loadNineDayForecast(lang: "en")
            XCTAssertEqual(NineDayForecastChartData(forecast: model.nineDayWeatherForecast).days.first?.highCelsius, 31)
            XCTAssertNotNil(model.lastChecked)
            XCTAssertFalse(model.isLoading)
        }
    }

    func testFailedReloadRetainsPriorChartAndTimestampUntilRecovery() {
        ForecastChartMockURLProtocol.handler = { try Self.response($0, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261018")])) }
        onMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadNineDayForecast(lang: "en")
            let checked = model.lastChecked
            ForecastChartMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.loadNineDayForecast(lang: "en")
            XCTAssertEqual(NineDayForecastChartData(forecast: model.nineDayWeatherForecast).days.first?.id, "20261018")
            XCTAssertEqual(model.lastChecked, checked)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertFalse(model.isLoading)
            ForecastChartMockURLProtocol.handler = { try Self.response($0, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261019")])) }
            await model.loadNineDayForecast(lang: "en")
            XCTAssertNil(model.errorMessage)
            XCTAssertEqual(NineDayForecastChartData(forecast: model.nineDayWeatherForecast).days.first?.id, "20261019")
        }
    }

    func testLanguageChangeFailureClearsOldChartAndFullForecast() {
        ForecastChartMockURLProtocol.handler = { try Self.response($0, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261018")])) }
        onMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadNineDayForecast(lang: "en")
            ForecastChartMockURLProtocol.handler = { request in
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
                XCTAssertEqual(query?.first(where: { $0.name == "lang" })?.value, "tc")
                throw URLError(.timedOut)
            }
            await model.loadNineDayForecast(lang: "tc")
            XCTAssertNil(model.lastChecked)
            XCTAssertTrue(NineDayForecastChartData(forecast: model.nineDayWeatherForecast).days.isEmpty)
            XCTAssertNil(model.nineDayWeatherForecast.weatherForecast)
            XCTAssertNotNil(model.errorMessage)
        }
    }

    func testFreshEmptyResponseClearsPreviousChartAndSelection() {
        ForecastChartMockURLProtocol.handler = { try Self.response($0, forecast: NineDayWeatherForecast(weatherForecast: [self.day("20261018")])) }
        onMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadNineDayForecast(lang: "en")
            ForecastChartMockURLProtocol.handler = { try Self.response($0, forecast: NineDayWeatherForecast(weatherForecast: [])) }
            await model.loadNineDayForecast(lang: "en")
            let chart = NineDayForecastChartData(forecast: model.nineDayWeatherForecast)
            XCTAssertTrue(chart.days.isEmpty)
            XCTAssertNil(chart.selectedDay(id: "20261018"))
            XCTAssertNil(model.errorMessage)
            XCTAssertNotNil(model.lastChecked)
        }
    }

    private func day(_ date: String, low: Int? = 20, high: Int? = 28) -> WeatherForecast {
        WeatherForecast(forecastDate: date,
                        forecastMaxtemp: ForecastValueWithUnit(value: high, unit: "C"),
                        forecastMintemp: ForecastValueWithUnit(value: low, unit: "C"))
    }
    private func model(_ days: [WeatherForecast]) -> NineDayForecastChartData {
        NineDayForecastChartData(forecast: NineDayWeatherForecast(weatherForecast: days))
    }
    private func iso(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private static func response(_ request: URLRequest, forecast: NineDayWeatherForecast) throws -> (HTTPURLResponse, Data) {
        (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)),
         try JSONEncoder().encode(forecast))
    }
    private func onMainActor(_ operation: @escaping @MainActor (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Forecast refresh completes")
        let client = service!
        Task { @MainActor in
            do { try await operation(client) } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}

private final class ForecastChartMockURLProtocol: URLProtocol {
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
