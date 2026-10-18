import Foundation
import CoreLocation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class NearbyWeatherTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_792_310_400)

    func testNearestStationSkipsCloserMissingReadingsAndUsesCatalogCoordinates() throws {
        let origin = station("sha-tin")
        let report = report([TemperatureData(place: "Sha Tin", unit: "C", value: nil),
                             TemperatureData(place: "Tai Po", unit: "C", value: 27)])
        let match = try XCTUnwrap(NearbyWeatherMatch.nearest(in: report, to: location(origin.coordinate)))
        XCTAssertEqual(match.id, "tai-po")
        XCTAssertGreaterThan(match.distanceMeters, 0)
        XCTAssertEqual(match.observation.reading?.value, 27)
    }

    func testExactStationLocationPreservesGenuineZeroAndBilingualReading() throws {
        let source = report([TemperatureData(place: "沙田", unit: "C", value: 0)])
        let match = try XCTUnwrap(NearbyWeatherMatch.nearest(in: source, to: location(station("sha-tin").coordinate)))
        XCTAssertEqual(match.id, "sha-tin")
        XCTAssertEqual(match.distanceMeters, 0, accuracy: 0.01)
        XCTAssertEqual(match.observation.reading?.value, 0)
        XCTAssertEqual(match.observation.selection(lang: "en", observationTime: "observed").station.place, "Sha Tin")
    }

    func testMissingAndUnsupportedUnitsNeverBecomeNearbyMeasurements() {
        let source = report([TemperatureData(place: "Sha Tin", unit: "K", value: 300),
                             TemperatureData(place: "Tai Po", unit: "C", value: nil)])
        XCTAssertNil(NearbyWeatherMatch.nearest(in: source, to: location(station("sha-tin").coordinate)))
        XCTAssertNil(NearbyWeatherMatch.nearest(in: RegionWeatherForecast(), to: location(station("sha-tin").coordinate)))
    }

    func testDistantAndInvalidRadiusRequestsReturnNoHongKongStation() {
        let source = report([TemperatureData(place: "Sha Tin", unit: "C", value: 27)])
        XCTAssertNil(NearbyWeatherMatch.nearest(in: source, to: location(.init(latitude: 35.68, longitude: 139.69))))
        for radius in [-1.0, Double.infinity, Double.nan] {
            XCTAssertNil(NearbyWeatherMatch.nearest(in: source, to: location(station("sha-tin").coordinate), maximumDistance: radius))
        }
    }

    func testEqualDistanceUsesStableStationIDRegardlessOfCatalogOrder() throws {
        let coordinate = station("sha-tin").coordinate
        let first = StationCoordinate(id: "a", placeTC: "甲", placeEN: "Alpha", coordinate: coordinate)
        let second = StationCoordinate(id: "b", placeTC: "乙", placeEN: "Beta", coordinate: coordinate)
        let source = report([TemperatureData(place: "Alpha", unit: "C", value: 25),
                             TemperatureData(place: "Beta", unit: "C", value: 28)])
        for catalog in [[first, second], [second, first]] {
            XCTAssertEqual(NearbyWeatherMatch.nearest(in: source, to: location(coordinate), catalog: catalog)?.id, "a")
        }
    }

    func testNearestSelectionIsIndependentOfExplorerSearchAndFavorites() {
        let source = report([TemperatureData(place: "Sha Tin", unit: "C", value: 27)])
        let filtered = RegionalWeatherExplorerResults(report: source, query: "Tai Po", filter: .favorites,
                                                     favoriteIDs: [], lang: "en")
        XCTAssertTrue(filtered.stations.isEmpty)
        XCTAssertEqual(NearbyWeatherMatch.nearest(in: source, to: location(station("sha-tin").coordinate))?.id, "sha-tin")
    }

    func testLocationPolicyRejectsStaleFutureAndInvalidAccuracyFixes() {
        let coordinate = station("sha-tin").coordinate
        for fix in [location(coordinate, age: 61), location(coordinate, age: -6),
                    location(coordinate, accuracy: -1), location(coordinate, accuracy: .infinity)] {
            XCTAssertFalse(LocationFixPolicy.isValid(fix, at: Self.now))
        }
        XCTAssertTrue(LocationFixPolicy.isValid(location(coordinate, age: 60), at: Self.now))
        XCTAssertTrue(LocationFixPolicy.isValid(location(coordinate, age: -5), at: Self.now))
    }

    func testApproximateLocationIsAcceptedAndExpiresAfterFiveMinutes() {
        let coordinate = station("sha-tin").coordinate
        XCTAssertTrue(LocationFixPolicy.isValid(location(coordinate, accuracy: 5000), at: Self.now))
        XCTAssertFalse(LocationFixPolicy.isExpired(location(coordinate, age: 300), at: Self.now))
        XCTAssertTrue(LocationFixPolicy.isExpired(location(coordinate, age: 301), at: Self.now))
    }

    func testRetainedWeatherAfterFailedRefreshCannotProduceCurrentNearbyMatch() {
        let fix = location(station("sha-tin").coordinate)
        let source = report([TemperatureData(place: "Sha Tin", unit: "C", value: 27)])
        let section = WeatherDashboardSection(value: source, errorMessage: "Network error", lastChecked: Self.now)
        guard case .unavailable = NearbyWeatherState(location: fix, now: Self.now, section: section) else {
            return XCTFail("A failed refresh must not reuse previous observations as a current nearby result")
        }
    }

    func testPendingOrUnconfirmedWeatherDoesNotPublishNearbyMatch() {
        let fix = location(station("sha-tin").coordinate)
        let source = report([TemperatureData(place: "Sha Tin", unit: "C", value: 27)])
        let loading = WeatherDashboardSection(value: source, isLoading: true, lastChecked: Self.now)
        guard case .loading = NearbyWeatherState(location: fix, now: Self.now, section: loading) else { return XCTFail("Expected loading") }
        let unconfirmed = WeatherDashboardSection(value: source)
        guard case .unavailable = NearbyWeatherState(location: fix, now: Self.now, section: unconfirmed) else { return XCTFail("Expected unavailable") }
    }

    func testNearbyPresentationDistinguishesFreshMatchNoStationAndExpiredLocation() {
        let fix = location(station("sha-tin").coordinate)
        let section = WeatherDashboardSection(value: report([TemperatureData(place: "Sha Tin", unit: "C", value: 27)]), lastChecked: Self.now)
        guard case .match(let match) = NearbyWeatherState(location: fix, now: Self.now, section: section) else { return XCTFail("Expected match") }
        XCTAssertEqual(match.id, "sha-tin")
        guard case .expired = NearbyWeatherState(location: fix, now: Self.now.addingTimeInterval(301), section: section) else { return XCTFail("Expected expired") }
        let empty = WeatherDashboardSection(value: report([]), lastChecked: Self.now)
        guard case .noNearby = NearbyWeatherState(location: fix, now: Self.now, section: empty) else { return XCTFail("Expected no nearby reporting station") }
    }

    func testDistanceFormattingRemainsMetricInBothLanguages() {
        for locale in [Locale(identifier: "en_HK"), Locale(identifier: "zh_Hant_HK")] {
            let short = NearbyWeatherFormatting.distance(250, locale: locale)
            let long = NearbyWeatherFormatting.distance(1250, locale: locale)
            XCTAssertTrue(short.contains("250"))
            XCTAssertTrue(long.contains("1.2") || long.contains("1.3"))
            XCTAssertFalse(short.contains("ft"))
            XCTAssertFalse(long.contains("mi"))
        }
    }

    func testPermissionPurposeIsLocalizedInBothTestResources() throws {
        let bundle = Bundle(for: Self.self)
        for language in ["en", "zh-Hant"] {
            let url = try XCTUnwrap(bundle.url(forResource: language, withExtension: "lproj"))
            let localized = try XCTUnwrap(Bundle(url: url))
            let purpose = localized.localizedString(forKey: "NSLocationWhenInUseUsageDescription", value: nil, table: "InfoPlist")
            XCTAssertNotEqual(purpose, "NSLocationWhenInUseUsageDescription")
            XCTAssertFalse(purpose.isEmpty)
        }
    }

    func testInitializationAndIdleAuthorizationCallbacksNeverPromptOrLocate() {
        onMainActor {
            let client = FakeLocationClient(status: .notDetermined)
            let model = LocationManager(client: client, now: { Self.now })
            client.onEvent?(.authorization(.notDetermined))
            client.onEvent?(.authorization(.authorizedWhenInUse))
            XCTAssertEqual(client.authorizationRequests, 0)
            XCTAssertEqual(client.fixRequests, 0)
            XCTAssertFalse(model.isLocating)
            XCTAssertNil(model.location)
        }
    }

    func testUserRequestPromptsWhenInUseOnceThenGetsOneFix() {
        onMainActor {
            let client = FakeLocationClient(status: .notDetermined)
            let model = LocationManager(client: client, now: { Self.now })
            client.onAuthorize = {
                client.onEvent?(.authorization(.notDetermined))
                client.authorizationStatus = .authorizedWhenInUse
                client.onEvent?(.authorization(.authorizedWhenInUse))
                client.onEvent?(.authorization(.authorizedWhenInUse))
            }
            client.onRequest = { client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate)])) }
            await model.locate()
            XCTAssertEqual(client.authorizationRequests, 1)
            XCTAssertEqual(client.fixRequests, 1)
            XCTAssertEqual(client.stops, 1)
            XCTAssertNotNil(model.location)
            XCTAssertNil(model.failure)
            XCTAssertFalse(model.isLocating)
        }
    }

    func testExistingAuthorizationDoesNotPromptAgain() {
        onMainActor {
            for status in [LocationAuthorization.authorizedWhenInUse, .authorizedAlways] {
                let client = FakeLocationClient(status: status)
                let model = LocationManager(client: client, now: { Self.now })
                client.onRequest = { client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate)])) }
                await model.locate()
                XCTAssertEqual(client.authorizationRequests, 0)
                XCTAssertEqual(client.fixRequests, 1)
                XCTAssertNotNil(model.location)
            }
        }
    }

    func testDeniedAndRestrictedAccessHaveManualFallbackStateWithoutLocationRequest() {
        onMainActor {
            for (status, failure) in [(LocationAuthorization.denied, LocationLookupError.denied), (.restricted, .restricted)] {
                let client = FakeLocationClient(status: status)
                let model = LocationManager(client: client, now: { Self.now })
                await model.locate()
                XCTAssertEqual(client.authorizationRequests, 0)
                XCTAssertEqual(client.fixRequests, 0)
                XCTAssertEqual(model.failure, failure)
                XCTAssertNil(model.location)
                XCTAssertFalse(model.isLocating)
            }
        }
    }

    func testStaleFixDoesNotBecomeLocationAndLookupStops() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            client.onRequest = { client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate, age: 61)])) }
            await model.locate()
            XCTAssertEqual(model.failure, .unavailable)
            XCTAssertNil(model.location)
            XCTAssertEqual(client.stops, 1)
        }
    }

    func testNewestValidFixIsSelectedFromMixedResults() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            client.onRequest = {
                client.onEvent?(.locations([self.location(self.station("tai-po").coordinate, age: 30),
                                           self.location(self.station("sha-tin").coordinate),
                                           self.location(self.station("tai-po").coordinate, age: -10)]))
            }
            await model.locate()
            XCTAssertEqual(model.location?.coordinate.latitude, self.station("sha-tin").coordinate.latitude)
            XCTAssertNil(model.failure)
        }
    }

    func testLocationFailureAndRetryPerformNewRequestWithoutCachedFix() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            client.onRequest = { client.onEvent?(.failure(CLError(.locationUnknown))) }
            await model.locate()
            XCTAssertEqual(model.failure, .unavailable)
            client.onRequest = { client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate)])) }
            await model.locate()
            XCTAssertEqual(client.fixRequests, 2)
            XCTAssertNotNil(model.location)
            XCTAssertNil(model.failure)
            client.onRequest = { client.onEvent?(.failure(CLError(.denied))) }
            await model.locate()
            XCTAssertEqual(client.fixRequests, 3)
            XCTAssertNil(model.location)
            XCTAssertEqual(model.failure, .denied)
        }
    }

    func testLookupTimesOutAndStopsWithoutInventingCoordinates() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now }, timeoutNanoseconds: 1_000_000)
            await model.locate()
            XCTAssertEqual(model.failure, .timedOut)
            XCTAssertNil(model.location)
            XCTAssertFalse(model.isLocating)
            XCTAssertEqual(client.stops, 1)
        }
    }

    func testCancelStopsPendingLookupAndIgnoresLateCallback() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            let pending = Task { @MainActor in await model.locate() }
            await self.started(client)
            model.cancel()
            await pending.value
            client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate)]))
            XCTAssertNil(model.location)
            XCTAssertNil(model.failure)
            XCTAssertFalse(model.isLocating)
            XCTAssertEqual(client.stops, 1)
        }
    }

    func testTaskCancellationAndDuplicateLookupDoNotStartAnotherFix() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            let pending = Task { @MainActor in await model.locate() }
            await self.started(client)
            await model.locate()
            XCTAssertEqual(client.fixRequests, 1)
            pending.cancel()
            await pending.value
            XCTAssertNil(model.location)
            XCTAssertNil(model.failure)
            XCTAssertFalse(model.isLocating)
            XCTAssertEqual(client.stops, 1)
        }
    }

    func testClearingCompletedLookupDiscardsInMemoryCoordinate() {
        onMainActor {
            let client = FakeLocationClient(status: .authorizedWhenInUse)
            let model = LocationManager(client: client, now: { Self.now })
            client.onRequest = { client.onEvent?(.locations([self.location(self.station("sha-tin").coordinate)])) }
            await model.locate()
            XCTAssertNotNil(model.location)
            model.cancel()
            XCTAssertNil(model.location)
            XCTAssertNil(model.failure)
        }
    }

    private func station(_ id: String) -> StationCoordinate { StationCoordinateStore.station(withID: id)! }
    private func report(_ readings: [TemperatureData]) -> RegionWeatherForecast {
        RegionWeatherForecast(temperature: TemperatureInfo(data: readings))
    }
    private func location(_ coordinate: CLLocationCoordinate2D, age: TimeInterval = 0, accuracy: Double = 100) -> CLLocation {
        CLLocation(coordinate: coordinate, altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: -1,
                   timestamp: Self.now.addingTimeInterval(-age))
    }
    @MainActor private func started(_ client: FakeLocationClient) async {
        for _ in 0..<100 {
            if client.fixRequests > 0 { return }
            await Task.yield()
        }
        XCTFail("Lookup did not start")
    }
    private func onMainActor(_ operation: @escaping @MainActor () async throws -> Void) {
        let finished = expectation(description: "Nearby location operation completes")
        Task { @MainActor in
            do { try await operation() } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}

@MainActor
private final class FakeLocationClient: LocationRequestClient {
    var authorizationStatus: LocationAuthorization
    var onEvent: ((LocationClientEvent) -> Void)?
    var onAuthorize: (() -> Void)?
    var onRequest: (() -> Void)?
    var authorizationRequests = 0
    var fixRequests = 0
    var stops = 0
    init(status: LocationAuthorization) { authorizationStatus = status }
    func requestWhenInUseAuthorization() { authorizationRequests += 1; onAuthorize?() }
    func requestLocation() { fixRequests += 1; onRequest?() }
    func stop() { stops += 1 }
}
