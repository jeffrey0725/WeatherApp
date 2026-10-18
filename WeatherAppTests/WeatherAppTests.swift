import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class WeatherAppTests: XCTestCase {
    private var session: URLSession!
    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [WeatherMockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = WeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        WeatherMockURLProtocol.handler = nil
        session = nil
        service = nil
        super.tearDown()
    }

    func testCurrentReportDecodesNighttimeUVAndEmptyMessages() throws {
        let report: RegionWeatherForecast = try decode(#"""
        {"uvindex":"","warningMessage":"","tcmessage":"","icon":[71],
         "temperature":{"data":[{"place":"Hong Kong Observatory","value":27,"unit":"C"}]},
         "humidity":{"data":[{"place":"Hong Kong Observatory","value":78,"unit":"percent"}]}}
        """#)
        XCTAssertNil(report.uvindex)
        XCTAssertNil(report.warningMessage)
        XCTAssertNil(report.tcmessage)
        XCTAssertEqual(report.icon, [71])
        XCTAssertEqual(report.temperature?.data?.first?.value, 27)
        XCTAssertEqual(report.humidity?.data?.first?.value, 78)
    }

    func testCurrentReportDecodesUVObjectAndMessageVariants() throws {
        let report: RegionWeatherForecast = try decode(#"""
        {"uvindex":{"data":[{"place":"King's Park","value":6.5,"desc":"High"}]},
         "warningMessage":["Thunderstorm warning",""],"tcmessage":"Cyclone information",
         "specialWxTips":["Weather tip"]}
        """#)
        XCTAssertEqual(report.uvindex?.data?.first?.value, 6.5)
        XCTAssertEqual(report.warningMessage, ["Thunderstorm warning"])
        XCTAssertEqual(report.tcmessage, ["Cyclone information"])
        XCTAssertEqual(report.specialWxTips, ["Weather tip"])
    }

    func testCurrentReportAcceptsMissingAndNullFields() throws {
        let report: RegionWeatherForecast = try decode(#"{"uvindex":null,"warningMessage":null}"#)
        XCTAssertNil(report.temperature)
        XCTAssertNil(report.uvindex)
        XCTAssertNil(report.warningMessage)
    }

    func testUnexpectedMessageShapeIsRejected() {
        XCTAssertThrowsError(try decode(#"{"warningMessage":{"unexpected":true}}"#) as RegionWeatherForecast)
    }

    func testRainfallKeepsObservationPeriodAndMaintenanceFlag() throws {
        let report: RegionWeatherForecast = try decode(#"""
        {"rainfall":{"startTime":"2026-10-12T08:00:00+08:00","endTime":"2026-10-12T09:00:00+08:00",
         "data":[{"place":"Sha Tin","unit":"mm","main":"TRUE"}]}}
        """#)
        XCTAssertEqual(report.rainfall?.endTime, "2026-10-12T09:00:00+08:00")
        XCTAssertEqual(report.rainfall?.data?.first?.main, "TRUE")
        XCTAssertNil(report.rainfall?.data?.first?.max)
    }

    func testNineDayForecastPreservesQualitativeRainLikelihood() throws {
        let forecast: NineDayWeatherForecast = try decode(#"""
        {"weatherForecast":[{"forecastDate":"20261012","week":"Monday","forecastWind":"Easterly winds.",
         "forecastMaxtemp":{"value":29,"unit":"C"},"forecastMintemp":{"value":25,"unit":"C"},
         "forecastMaxrh":{"value":95,"unit":"percent"},"forecastMinrh":{"value":70,"unit":"percent"},
         "ForecastIcon":54,"PSR":"Medium High"}]}
        """#)
        let day = try XCTUnwrap(forecast.weatherForecast?.first)
        XCTAssertEqual(day.forecastMintemp?.value, 25)
        XCTAssertEqual(day.forecastMaxrh?.value, 95)
        XCTAssertEqual(day.PSR, "Medium High")
    }

    func testWarningsRespectCancellationAndExpiry() throws {
        let warnings: WeatherWarningSummary = try decode(#"""
        {"WHOT":{"code":"WHOT","actionCode":"ISSUE"},
         "WTCSGNL":{"code":"CANCEL","actionCode":"CANCEL"},
         "WRAIN":{"code":"WRAINR","actionCode":"CANCEL"},
         "WTS":{"code":"WTS","actionCode":"EXTEND","expireTime":"2026-10-12T10:00:00+08:00"}}
        """#)
        let before = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-12T09:00:00+08:00"))
        XCTAssertTrue(warnings["WHOT"]?.isActive(at: before) == true)
        XCTAssertFalse(warnings["WTCSGNL"]?.isActive(at: before) == true)
        XCTAssertFalse(warnings["WRAIN"]?.isActive(at: before) == true)
        XCTAssertTrue(warnings["WTS"]?.isActive(at: before) == true)
        XCTAssertFalse(warnings["WTS"]?.isActive(at: before.addingTimeInterval(7200)) == true)
        XCTAssertFalse(WeatherWarning().isActive())
    }

    func testEmptyWarningSummaryIsValid() throws {
        let warnings: WeatherWarningSummary = try decode("{}")
        XCTAssertTrue(warnings.isEmpty)
    }

    func testWarningDetailsIncludePreNumberEightAnnouncement() throws {
        let info: WeatherWarningInformation = try decode(#"""
        {"details":[{"warningStatementCode":"WTCPRE8","contents":["No. 8 is expected.","Second paragraph."],
         "updateTime":"2026-10-12T09:00:00+08:00"}]}
        """#)
        XCTAssertEqual(info.details?.first?.warningStatementCode, "WTCPRE8")
        XCTAssertEqual(info.details?.first?.contents?.count, 2)
    }

    func testSpecialTipsAcceptPresentAndMissingCollections() throws {
        let tips: SpecialWeatherTips = try decode(#"{"swt":[{"desc":"Localised heavy rain."}]}"#)
        let empty: SpecialWeatherTips = try decode("{}")
        XCTAssertEqual(tips.swt?.first?.desc, "Localised heavy rain.")
        XCTAssertNil(empty.swt)
    }

    func testMissingMeasurementsAreNotReportedAsZero() {
        XCTAssertNotEqual(WeatherFormatting.measurement(nil, unit: "C"), "0 °C")
        XCTAssertEqual(WeatherFormatting.measurement(0, unit: "mm"), "0 mm")
        XCTAssertEqual(WeatherFormatting.measurement(78, unit: "percent"), "78%")
        XCTAssertNil(WeatherFormatting.timestamp("invalid date"))
        XCTAssertNotNil(WeatherFormatting.timestamp("2026-10-12T09:00:00+08:00"))
    }

    func testAllSixRequestsUseDocumentedDataTypesAndLanguages() {
        WeatherMockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(components.host, "data.weather.gov.hk")
            XCTAssertEqual(components.path, "/weatherAPI/opendata/weather.php")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            let type = try XCTUnwrap(query["dataType"])
            let languages = ["flw":"tc","fnd":"en","rhrread":"sc","warnsum":"tc","warningInfo":"tc","swt":"tc"]
            XCTAssertEqual(query["lang"], languages[type])
            let bodies = [
                "flw": #"{"forecastDesc":"Local forecast"}"#,
                "fnd": #"{"weatherForecast":[{"forecastDate":"20261012"}]}"#,
                "rhrread": #"{"humidity":{"data":[{"value":78}]}}"#,
                "warnsum": #"{"WHOT":{"code":"WHOT","actionCode":"ISSUE"}}"#,
                "warningInfo": #"{"details":[{"warningStatementCode":"WHOT","contents":["Warning detail"]}]}"#,
                "swt": #"{"swt":[{"desc":"Special tip"}]}"#
            ]
            return try Self.response(request, body: XCTUnwrap(bodies[type]))
        }
        perform { service in
            let local = try await service.localForecast(lang: "tc")
            let nine = try await service.nineDayForecast(lang: "en")
            let current = try await service.currentReport(lang: "sc")
            let summary = try await service.warningSummary(lang: "tc")
            let info = try await service.warningInformation(lang: "tc")
            let tips = try await service.specialTips(lang: "tc")
            XCTAssertEqual(local.forecastDesc, "Local forecast")
            XCTAssertEqual(nine.weatherForecast?.count, 1)
            XCTAssertEqual(current.humidity?.data?.first?.value, 78)
            XCTAssertEqual(summary["WHOT"]?.code, "WHOT")
            XCTAssertEqual(info.details?.first?.contents, ["Warning detail"])
            XCTAssertEqual(tips.swt?.first?.desc, "Special tip")
        }
    }

    func testHTTPFailureIsReported() {
        WeatherMockURLProtocol.handler = { try Self.response($0, status: 503, body: "{}") }
        perform { service in
            do { _ = try await service.localForecast(lang: "tc"); XCTFail("Expected HTTP error") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .httpStatus(503)) }
        }
    }

    func testMalformedJSONIsReportedWithoutCrashing() {
        WeatherMockURLProtocol.handler = { try Self.response($0, body: "<html>Unavailable</html>") }
        perform { service in
            do { _ = try await service.nineDayForecast(lang: "en"); XCTFail("Expected decoding error") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
        }
    }

    func testNetworkFailureCompletesWithError() {
        WeatherMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        perform { service in
            do { _ = try await service.currentReport(lang: "tc"); XCTFail("Expected network error") }
            catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        }
    }

    func testCancellationCompletesWithError() {
        WeatherMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        perform { service in
            do { _ = try await service.localForecast(lang: "tc"); XCTFail("Expected cancellation") }
            catch { XCTAssertEqual((error as? URLError)?.code, .cancelled) }
        }
    }

    func testInvalidURLIsReportedBeforeRequest() {
        let invalid = WeatherService(session: session, baseURL: "not a url")
        perform { _ in
            do { _ = try await invalid.localForecast(lang: "en"); XCTFail("Expected invalid URL") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .invalidURL) }
        }
    }

    func testViewModelEndsLoadingAfterFailure() {
        WeatherMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadLocalForecast(lang: "tc")
            XCTAssertFalse(model.isLoading)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertNil(model.lastChecked)
        }
    }

    func testViewModelPreservesPreviousForecastWhenRefreshFails() {
        WeatherMockURLProtocol.handler = { try Self.response($0, body: #"{"forecastDesc":"Previous forecast"}"#) }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadLocalForecast(lang: "tc")
            let previousCheck = model.lastChecked
            WeatherMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
            await model.loadLocalForecast(lang: "tc")
            XCTAssertEqual(model.localWeatherForecast.forecastDesc, "Previous forecast")
            XCTAssertEqual(model.lastChecked, previousCheck)
            XCTAssertFalse(model.isLoading)
            XCTAssertNotNil(model.errorMessage)
        }
    }

    func testViewModelDoesNotShowCancellationAsFailure() {
        WeatherMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadCurrentReport(lang: "tc")
            XCTAssertFalse(model.isLoading)
            XCTAssertNil(model.errorMessage)
            XCTAssertNil(model.lastChecked)
        }
    }

    func testWarningSnapshotRequiresAllEndpointsToSucceed() {
        WeatherMockURLProtocol.handler = { request in
            let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            if items?.first(where: { $0.name == "dataType" })?.value == "warningInfo" {
                return try Self.response(request, status: 503, body: "{}")
            }
            return try Self.response(request, body: #"{"WHOT":{"code":"WHOT","actionCode":"ISSUE"}}"#)
        }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadWarnings(lang: "tc")
            XCTAssertFalse(model.isLoading)
            XCTAssertNotNil(model.errorMessage)
            XCTAssertNil(model.lastChecked)
            XCTAssertTrue(model.warningReport.summary.isEmpty)
        }
    }

    func testCurrentReportMapsBothStationLanguagesAndKeepsUnknownStations() {
        WeatherMockURLProtocol.handler = { try Self.response($0, body: #"""
        {"temperature":{"data":[{"place":"Hong Kong Observatory","value":27,"unit":"C"},
         {"place":"香港天文台","value":27,"unit":"C"},{"place":"New station","value":26,"unit":"C"}]}}
        """#) }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadCurrentReport(lang: "tc")
            let stations = try XCTUnwrap(model.regionWeatherForecast.temperature?.data)
            XCTAssertEqual(stations.count, 3)
            XCTAssertEqual(stations[0].latitude, 22.3019)
            XCTAssertEqual(stations[1].longitude, 114.1740)
            XCTAssertNil(stations[2].latitude)
            XCTAssertEqual(stations[2].value, 26)
        }
    }

    func testDashboardSelectsObservatoryReadingsInBothLanguages() throws {
        for place in ["Hong Kong Observatory", "香港天文台"] {
            let report: RegionWeatherForecast = try decode("""
            {"temperature":{"recordTime":"2026-10-12T09:00:00+08:00","data":[
             {"place":"Sha Tin","value":25,"unit":"C"},{"place":"\(place)","value":28,"unit":"C"}]},
             "humidity":{"recordTime":"2026-10-12T08:50:00+08:00","data":[
             {"place":"Other station","value":70},{"place":"\(place)","value":81,"unit":"percent"}]}}
            """)
            XCTAssertEqual(report.observatoryTemperature?.value, 28)
            XCTAssertEqual(report.observatoryHumidity?.value, 81)
            XCTAssertNotEqual(report.temperature?.recordTime, report.humidity?.recordTime)
        }
    }

    func testDashboardDoesNotSubstituteAnotherStationForMissingObservatoryData() throws {
        let report: RegionWeatherForecast = try decode(#"""
        {"temperature":{"data":[{"place":"Sha Tin","value":25,"unit":"C"}]},
         "humidity":{"data":[{"place":"Other station","value":70}]}}
        """#)
        XCTAssertNil(report.observatoryTemperature)
        XCTAssertNil(report.observatoryHumidity)
    }

    func testForecastPreviewPreservesActualDatesAndHandlesShortForecasts() throws {
        let forecast: NineDayWeatherForecast = try decode(#"""
        {"weatherForecast":[{"forecastDate":"20261013"},{"forecastDate":"20261014"},
         {"forecastDate":"20261015"},{"forecastDate":"20261016"}]}
        """#)
        XCTAssertEqual(forecast.preview.compactMap(\.forecastDate), ["20261013", "20261014", "20261015"])
        XCTAssertTrue(NineDayWeatherForecast().preview.isEmpty)
        let short = NineDayWeatherForecast(weatherForecast: [WeatherForecast(forecastDate: "20261013")])
        XCTAssertEqual(short.preview.count, 1)
    }

    func testWarningCardsUseDetailsForTheCurrentSignalSubtype() throws {
        let summary: WeatherWarningSummary = try decode(#"{"WRAIN":{"code":"WRAINR","actionCode":"ISSUE"}}"#)
        let info: WeatherWarningInformation = try decode(#"""
        {"details":[{"warningStatementCode":"WRAIN","subtype":"WRAINA","contents":["Old amber signal"]},
         {"warningStatementCode":"WRAIN","subtype":"WRAINR","contents":["Red signal","Advice"]},
         {"warningStatementCode":"WHOT","contents":["Other warning"]}]}
        """#)
        let report = WeatherWarningReport(summary: summary, information: info)
        let warning = try XCTUnwrap(summary["WRAIN"])
        XCTAssertEqual(report.details(for: "WRAIN", warning: warning), "Red signal\n\nAdvice")
        XCTAssertEqual(report.activeWarningKeys(), ["WRAIN"])
    }

    func testDashboardLoadsAllSectionsAndUsesTheSelectedLanguage() {
        let requests = ["en", "tc"].flatMap { lang in
            WeatherDataType.allCases.map { "\(lang)-\($0.rawValue)" }
        }
        let received = Dictionary(uniqueKeysWithValues: requests.map { ($0, expectation(description: $0)) })
        WeatherMockURLProtocol.handler = { request in
            let query = try Self.query(request)
            let key = "\(query["lang"] ?? "")-\(query["dataType"] ?? "")"
            try XCTUnwrap(received[key]).fulfill()
            return try Self.dashboardResponse(request)
        }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            for lang in ["en", "tc"] {
                await model.refresh(lang: lang)
                XCTAssertEqual(model.current.value?.observatoryTemperature?.value, 28)
                XCTAssertEqual(model.local.value?.forecastDesc, "Local forecast")
                XCTAssertEqual(model.forecast.value?.preview.first?.forecastDate, "20261013")
                XCTAssertEqual(model.warnings.value?.activeWarningKeys(), ["WHOT"])
                XCTAssertNotNil(model.current.lastChecked)
                XCTAssertNotNil(model.local.lastChecked)
                XCTAssertNotNil(model.forecast.lastChecked)
                XCTAssertNotNil(model.warnings.lastChecked)
                XCTAssertFalse(model.isLoading)
            }
        }
        wait(for: Array(received.values), timeout: 5)
    }

    func testDashboardForecastFailureKeepsCurrentWeatherAndWarningsAvailable() {
        WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0, failingType: "fnd") }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertNil(model.forecast.value)
            XCTAssertNil(model.forecast.lastChecked)
            XCTAssertNotNil(model.forecast.errorMessage)
            XCTAssertFalse(model.forecast.isLoading)
            XCTAssertNotNil(model.current.value)
            XCTAssertNotNil(model.local.value)
            XCTAssertNotNil(model.warnings.value)
            XCTAssertNil(model.current.errorMessage)
            XCTAssertFalse(model.isLoading)
        }
    }

    func testDashboardWarningFailureDoesNotPublishAnEmptyWarningReport() {
        WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0, failingType: "warningInfo") }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            await model.refresh(lang: "tc")
            XCTAssertNil(model.warnings.value)
            XCTAssertNil(model.warnings.lastChecked)
            XCTAssertNotNil(model.warnings.errorMessage)
            XCTAssertFalse(model.warnings.isLoading)
            XCTAssertNotNil(model.current.value)
            XCTAssertNotNil(model.local.value)
            XCTAssertNotNil(model.forecast.value)
            XCTAssertFalse(model.isLoading)
        }
    }

    func testDashboardKeepsPreviousDataOnFailureAndRecoversOnRetry() {
        WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0) }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            await model.refresh(lang: "en")
            let checked = model.current.lastChecked
            let warningCheck = model.warnings.lastChecked
            WeatherMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en")
            XCTAssertEqual(model.current.value?.observatoryTemperature?.value, 28)
            XCTAssertEqual(model.current.lastChecked, checked)
            XCTAssertEqual(model.warnings.value?.activeWarningKeys(), ["WHOT"])
            XCTAssertEqual(model.warnings.lastChecked, warningCheck)
            XCTAssertNotNil(model.current.errorMessage)
            XCTAssertNotNil(model.local.errorMessage)
            XCTAssertNotNil(model.forecast.errorMessage)
            XCTAssertNotNil(model.warnings.errorMessage)
            XCTAssertFalse(model.isLoading)
            WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0) }
            await model.refresh(lang: "en")
            XCTAssertNil(model.current.errorMessage)
            XCTAssertNil(model.local.errorMessage)
            XCTAssertNil(model.forecast.errorMessage)
            XCTAssertNil(model.warnings.errorMessage)
        }
    }

    func testDashboardCancellationClearsLoadingWithoutShowingErrors() {
        WeatherMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertFalse(model.isLoading)
            XCTAssertFalse(model.current.isLoading)
            XCTAssertFalse(model.local.isLoading)
            XCTAssertFalse(model.forecast.isLoading)
            XCTAssertFalse(model.warnings.isLoading)
            XCTAssertNil(model.current.errorMessage)
            XCTAssertNil(model.local.errorMessage)
            XCTAssertNil(model.forecast.errorMessage)
            XCTAssertNil(model.warnings.errorMessage)
            XCTAssertNil(model.warnings.value)
        }
    }

    func testNewLanguageFailureDoesNotDisplayThePreviousLanguageForecast() {
        WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0) }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadLocalForecast(lang: "en")
            XCTAssertNotNil(model.localWeatherForecast.forecastDesc)
            WeatherMockURLProtocol.handler = { request in
                XCTAssertEqual(try Self.query(request)["lang"], "tc")
                return try Self.response(request, status: 503, body: "{}")
            }
            await model.loadLocalForecast(lang: "tc")
            XCTAssertNil(model.localWeatherForecast.forecastDesc)
            XCTAssertNil(model.lastChecked)
            XCTAssertNotNil(model.errorMessage)
        }
    }

    func testDashboardLanguageFailureClearsPreviousLanguageSections() {
        WeatherMockURLProtocol.handler = { try Self.dashboardResponse($0) }
        performOnMainActor { service in
            let model = WeatherDashboardViewModel(service: service)
            await model.refresh(lang: "en")
            XCTAssertNotNil(model.current.value)
            WeatherMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "tc")
            XCTAssertNil(model.current.value)
            XCTAssertNil(model.local.value)
            XCTAssertNil(model.forecast.value)
            XCTAssertNil(model.warnings.value)
            XCTAssertNil(model.warnings.lastChecked)
            XCTAssertNotNil(model.warnings.errorMessage)
            XCTAssertFalse(model.isLoading)
        }
    }

    func testRepeatedRegionalLoadsMakeFreshRequestsAndPublishNewReadings() {
        let first = expectation(description: "First live regional request")
        let second = expectation(description: "Second live regional request")
        WeatherMockURLProtocol.handler = { request in
            XCTAssertEqual(try Self.query(request)["dataType"], "rhrread")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            first.fulfill()
            return try Self.response(request, body: #"{"temperature":{"data":[{"place":"Sha Tin","value":26,"unit":"C"}]}}"#)
        }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadCurrentReport(lang: "en")
            XCTAssertEqual(model.regionWeatherForecast.temperature?.data?.first?.value, 26)
            WeatherMockURLProtocol.handler = { request in
                XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
                second.fulfill()
                return try Self.response(request, body: #"{"temperature":{"data":[{"place":"Sha Tin","value":28,"unit":"C"}]}}"#)
            }
            await model.loadCurrentReport(lang: "en")
            XCTAssertEqual(model.regionWeatherForecast.temperature?.data?.first?.value, 28)
        }
        wait(for: [first, second], timeout: 5)
    }

    func testFailedWarningRefreshCannotTurnPreviousSnapshotIntoCurrentAllClear() {
        let now = Date()
        let expiry = ISO8601DateFormatter().string(from: now.addingTimeInterval(60))
        WeatherMockURLProtocol.handler = { request in
            let type = try Self.query(request)["dataType"]
            let body = type == "warnsum" ? "{\"WTS\":{\"code\":\"WTS\",\"actionCode\":\"ISSUE\",\"expireTime\":\"\(expiry)\"}}" : "{}"
            return try Self.response(request, body: body)
        }
        performOnMainActor { service in
            let model = WeatherViewModel(service: service)
            await model.loadWarnings(lang: "en")
            XCTAssertNotNil(model.lastChecked)
            WeatherMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.loadWarnings(lang: "en")
            let snapshot = WeatherWarningSnapshot(report: model.warningReport, lastChecked: model.lastChecked,
                                                  isRefreshing: model.isLoading, hasError: model.errorMessage != nil)
            XCTAssertEqual(snapshot.state, .previous)
            XCTAssertEqual(snapshot.activeWarningKeys(at: now.addingTimeInterval(120)), ["WTS"])
            XCTAssertNotEqual(snapshot.emptyMessageKey, "weather_no_warnings")
            WeatherMockURLProtocol.handler = { try Self.response($0, body: "{}") }
            await model.loadWarnings(lang: "en")
            let recovered = WeatherWarningSnapshot(report: model.warningReport, lastChecked: model.lastChecked,
                                                   isRefreshing: model.isLoading, hasError: model.errorMessage != nil)
            XCTAssertEqual(recovered.state, .current)
            XCTAssertTrue(recovered.activeWarningKeys(at: Date()).isEmpty)
        }
    }

    private static func query(_ request: URLRequest) throws -> [String: String] {
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private static func dashboardResponse(_ request: URLRequest, failingType: String? = nil) throws -> (HTTPURLResponse, Data) {
        let type = try XCTUnwrap(query(request)["dataType"])
        if type == failingType { return try response(request, status: 503, body: "{}") }
        let bodies = [
            "flw": #"{"forecastDesc":"Local forecast"}"#,
            "fnd": #"{"weatherForecast":[{"forecastDate":"20261013"}]}"#,
            "rhrread": #"{"temperature":{"data":[{"place":"Hong Kong Observatory","value":28,"unit":"C"}]}}"#,
            "warnsum": #"{"WHOT":{"name":"Very Hot Weather Warning","code":"WHOT","actionCode":"ISSUE"}}"#,
            "warningInfo": #"{"details":[{"warningStatementCode":"WHOT","contents":["Drink water."]}]}"#,
            "swt": #"{"swt":[]}"#
        ]
        return try response(request, body: XCTUnwrap(bodies[type]))
    }

    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private static func response(_ request: URLRequest, status: Int = 200, body: String) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (response, Data(body.utf8))
    }

    private func perform(_ operation: @escaping (WeatherService) async throws -> Void) {
        let completed = expectation(description: "Request completes")
        let client = service!
        Task.detached {
            do { try await operation(client) }
            catch { XCTFail("Unexpected error: \(error)") }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }

    private func performOnMainActor(_ operation: @escaping @MainActor (WeatherService) async throws -> Void) {
        let completed = expectation(description: "View model completes")
        let client = service!
        Task { @MainActor in
            do { try await operation(client) }
            catch { XCTFail("Unexpected error: \(error)") }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }
}

private final class WeatherMockURLProtocol: URLProtocol {
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
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
