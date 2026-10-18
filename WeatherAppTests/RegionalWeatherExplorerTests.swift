import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class RegionalWeatherExplorerTests: XCTestCase {
    func testEnglishSearchFindsChineseReadingAndUsesCatalogCoordinates() throws {
        let source = TemperatureData(place: "沙田", unit: "C", value: 27)
        let results = results([source], query: "  SHA TIN  ", lang: "en")
        XCTAssertEqual(results.stations.map(\.id), ["sha-tin"])
        let reading = try XCTUnwrap(results.mapReadings(lang: "en").first)
        XCTAssertEqual(reading.place, "Sha Tin")
        XCTAssertEqual(reading.value, 27)
        let station = try XCTUnwrap(StationCoordinateStore.station(withID: "sha-tin"))
        XCTAssertEqual(reading.latitude, station.coordinate.latitude)
        XCTAssertEqual(reading.longitude, station.coordinate.longitude)
        XCTAssertNil(source.latitude)
        XCTAssertEqual(source.place, "沙田")
    }

    func testChineseSearchFindsEnglishReading() {
        let results = results([TemperatureData(place: "Sha Tin", unit: "C", value: 25)], query: "沙田", lang: "tc")
        XCTAssertEqual(results.mapReadings(lang: "tc").map(\.place), ["沙田"])
        XCTAssertEqual(results.mapReadings(lang: "tc").map(\.value), [25])
    }

    func testFavoritesAndSearchAreIntersectedAndUnknownIDsAreIgnored() {
        let results = results([], query: "sha", filter: .favorites,
                              favoriteIDs: ["sha-tin", "tai-po", "unknown"], lang: "en")
        XCTAssertEqual(results.stations.map(\.id), ["sha-tin"])
        XCTAssertTrue(results.mapReadings(lang: "en").isEmpty)
    }

    func testAllStationsDoesNotRequireFavoritesAndUsesLocalizedOrdering() {
        let all = results([], query: "", favoriteIDs: [], lang: "en")
        XCTAssertEqual(all.stations.count, StationCoordinateStore.stationCoordinates.count)
        XCTAssertEqual(all.stations.map(\.id), StationCoordinateStore.stations(matching: "", lang: "en").map(\.id))
    }

    func testMissingReadingsAreCountedAndRealZeroIsPlotted() {
        let results = results([TemperatureData(place: "Sha Tin", unit: "C", value: 0),
                               TemperatureData(place: "Tai Po", unit: "C", value: nil)], query: "")
        XCTAssertEqual(results.unavailableCount, results.stations.count - 1)
        XCTAssertEqual(results.mapReadings(lang: "en").map(\.value), [0])
    }

    func testMissingStationDoesNotBorrowAnotherStationsTemperature() {
        let results = results([TemperatureData(place: "Hong Kong Observatory", unit: "C", value: 28)], query: "沙田")
        XCTAssertEqual(results.stations.count, 1)
        XCTAssertNil(results.stations.first?.reading)
        XCTAssertEqual(results.unavailableCount, 1)
        XCTAssertTrue(results.mapReadings(lang: "en").isEmpty)
    }

    func testEmptyFavoritesAndNoSearchMatchesProduceNoStations() {
        XCTAssertTrue(results([], query: "", filter: .favorites).stations.isEmpty)
        XCTAssertTrue(results([], query: "nonexistent station").stations.isEmpty)
        let favorites = results([], query: "", filter: .favorites, favoriteIDs: ["sha-tin"])
        XCTAssertEqual(favorites.stations.map(\.id), ["sha-tin"])
        XCTAssertTrue(results([], query: "", filter: .favorites, favoriteIDs: []).stations.isEmpty)
    }

    func testStationIdentitySurvivesNewAPIUUIDsAndLanguageChanges() throws {
        let english = TemperatureData(place: "Sha Tin", unit: "C", value: 27)
        let chinese = TemperatureData(place: "沙田", unit: "C", value: 28)
        XCTAssertNotEqual(english.id, chinese.id)
        let first = try XCTUnwrap(results([english], query: "Sha Tin").stations.first)
        let next = try XCTUnwrap(results([chinese], query: "沙田", lang: "tc").stations.first)
        XCTAssertEqual(first.id, next.id)
        XCTAssertEqual(next.reading?.value, 28)
    }

    func testListIncludesStationsWithoutReadingsWhileMapOmitsThem() {
        let source = results([TemperatureData(place: "Sha Tin", unit: "C", value: 27)], query: "")
        let list = source.listStations(sort: .name, lang: "en")
        XCTAssertEqual(list.count, StationCoordinateStore.stationCoordinates.count)
        XCTAssertEqual(source.mapReadings(lang: "en").count, 1)
        XCTAssertEqual(list.filter { $0.reading?.value == nil }.count, source.unavailableCount)
        XCTAssertEqual(Set(list.map(\.id)), Set(source.stations.map(\.id)))
    }

    func testWarmestSortRanksRealMeasurementsAndPlacesUnavailableStationsLast() {
        let source = results([TemperatureData(place: "Sha Tin", unit: "C", value: 27),
                              TemperatureData(place: "Tai Po", unit: "C", value: 30),
                              TemperatureData(place: "Hong Kong Observatory", unit: "C", value: 0)],
                             query: "", filter: .favorites,
                             favoriteIDs: ["sha-tin", "tai-po", "hong-kong-observatory", "cheung-chau"])
        XCTAssertEqual(source.listStations(sort: .warmest, lang: "en").map(\.id),
                       ["tai-po", "sha-tin", "hong-kong-observatory", "cheung-chau"])
    }

    func testCoolestSortKeepsNegativeAndZeroMeasurementsBeforeUnavailableRows() {
        let source = results([TemperatureData(place: "Sha Tin", unit: "C", value: 0),
                              TemperatureData(place: "Tai Po", unit: "C", value: -2),
                              TemperatureData(place: "Hong Kong Observatory", unit: "C", value: 7)],
                             query: "", filter: .favorites,
                             favoriteIDs: ["sha-tin", "tai-po", "hong-kong-observatory", "cheung-chau"])
        XCTAssertEqual(source.listStations(sort: .coolest, lang: "en").map(\.id),
                       ["tai-po", "sha-tin", "hong-kong-observatory", "cheung-chau"])
    }

    func testEqualTemperaturesUseStableStationNameOrdering() {
        let source = results([TemperatureData(place: "Tai Po", unit: "C", value: 27),
                              TemperatureData(place: "Sha Tin", unit: "C", value: 27)],
                             query: "", filter: .favorites, favoriteIDs: ["sha-tin", "tai-po"])
        for order in [RegionalStationSort.warmest, .coolest] {
            XCTAssertEqual(source.listStations(sort: order, lang: "en").map(\.id), ["sha-tin", "tai-po"])
        }
    }

    func testNameSortRetainsAlphabeticalOrderRegardlessOfAvailability() {
        let source = results([TemperatureData(place: "Sha Tin", unit: "C", value: 27)],
                             query: "", filter: .favorites, favoriteIDs: ["sha-tin", "hong-kong-observatory"])
        XCTAssertEqual(source.listStations(sort: .name, lang: "en").map(\.id), ["hong-kong-observatory", "sha-tin"])
        XCTAssertEqual(source.listStations(sort: .warmest, lang: "en").map(\.id), ["sha-tin", "hong-kong-observatory"])
    }

    func testUnsupportedUnitsAreNotRankedAgainstCelsius() {
        let source = results([TemperatureData(place: "Sha Tin", unit: "K", value: 300),
                              TemperatureData(place: "Tai Po", unit: "C", value: 27)],
                             query: "", filter: .favorites, favoriteIDs: ["sha-tin", "tai-po"])
        for order in [RegionalStationSort.warmest, .coolest] {
            XCTAssertEqual(source.listStations(sort: order, lang: "en").map(\.id), ["tai-po", "sha-tin"])
        }
        XCTAssertEqual(source.listStations(sort: .name, lang: "en").first?.reading?.unit, "K")
    }

    func testListSortDoesNotReintroduceStationsExcludedByBilingualSearchAndFavorites() {
        let source = results([TemperatureData(place: "沙田", unit: "C", value: 27),
                              TemperatureData(place: "Sham Shui Po", unit: "C", value: 30)],
                             query: "sha", filter: .favorites, favoriteIDs: ["sha-tin", "tai-po"])
        for order in RegionalStationSort.allCases {
            XCTAssertEqual(source.listStations(sort: order, lang: "tc").map(\.id), ["sha-tin"])
        }
        XCTAssertEqual(source.mapReadings(lang: "tc").map(\.place), ["沙田"])
    }

    func testEmptySearchAndFavoritesRemainEmptyInEveryListOrder() {
        for source in [results([], query: "no matching station"),
                       results([], query: "", filter: .favorites)] {
            for order in RegionalStationSort.allCases {
                XCTAssertTrue(source.listStations(sort: order, lang: "en").isEmpty)
            }
        }
    }

    func testListUsesSelectedLanguageForNamesAndOrdering() {
        let source = results([], query: "", filter: .favorites,
                             favoriteIDs: ["sha-tin", "tai-po", "hong-kong-observatory"])
        let ordered = source.listStations(sort: .name, lang: "tc")
        let names = ordered.map { $0.station.name(lang: "tc") }
        let expected = ["沙田", "大埔", "香港天文台"].sorted {
            $0.compare($1, options: [.caseInsensitive, .diacriticInsensitive, .numeric],
                       locale: AppLanguage.traditionalChinese.locale) == .orderedAscending
        }
        XCTAssertEqual(names, expected)
        XCTAssertEqual(Set(ordered.map(\.id)), ["sha-tin", "tai-po", "hong-kong-observatory"])
    }

    func testListSelectionCapturesReadingAndTimeWithoutMutatingAPISource() throws {
        let original = TemperatureData(place: "沙田", unit: "C", value: 27)
        let observation = try XCTUnwrap(results([original], query: "Sha Tin").stations.first)
        let selection = observation.selection(lang: "en", observationTime: "2026-10-18T12:00:00+08:00")
        let fresh = try XCTUnwrap(results([TemperatureData(place: "Sha Tin", unit: "C", value: 30)], query: "沙田").stations.first)
        XCTAssertEqual(selection.id, fresh.id)
        XCTAssertEqual(selection.station.value, 27)
        XCTAssertEqual(fresh.reading?.value, 30)
        XCTAssertEqual(selection.observationTime, "2026-10-18T12:00:00+08:00")
        XCTAssertEqual(selection.station.place, "Sha Tin")
        XCTAssertEqual(original.place, "沙田")
        XCTAssertNil(original.latitude)
    }

    func testUnavailableListSelectionKeepsCatalogIdentityAndHasNoInventedObservationTime() throws {
        for readings in [[], [TemperatureData(place: "Sha Tin", unit: "C", value: nil)]] {
            let observation = try XCTUnwrap(results(readings, query: "沙田").stations.first)
            let selection = observation.selection(lang: "tc", observationTime: "2026-10-18T12:00:00+08:00")
            XCTAssertEqual(selection.id, "sha-tin")
            XCTAssertEqual(selection.station.place, "沙田")
            XCTAssertNotNil(selection.station.latitude)
            XCTAssertNotNil(selection.station.longitude)
            XCTAssertNil(selection.station.value)
            XCTAssertNil(selection.observationTime)
        }
    }

    func testMapAndListUseTheSameStationIdentityValueAndCoordinatesIncludingZero() throws {
        let observation = try XCTUnwrap(results([TemperatureData(place: "Sha Tin", unit: "C", value: 0)], query: "沙田").stations.first)
        let pin = try XCTUnwrap(observation.mapReading(lang: "en"))
        let selection = observation.selection(lang: "en", observationTime: "2026-10-18T12:00:00+08:00")
        XCTAssertEqual(selection.id, "sha-tin")
        XCTAssertEqual(selection.station.value, pin.value)
        XCTAssertEqual(selection.station.value, 0)
        XCTAssertEqual(selection.station.place, pin.place)
        XCTAssertEqual(selection.station.latitude, pin.latitude)
        XCTAssertEqual(selection.station.longitude, pin.longitude)
        XCTAssertNotNil(selection.observationTime)
    }

    private func results(_ readings: [TemperatureData], query: String,
                         filter: RegionalStationFilter = .all, favoriteIDs: Set<String> = [],
                         lang: String = "en") -> RegionalWeatherExplorerResults {
        RegionalWeatherExplorerResults(report: RegionWeatherForecast(temperature: TemperatureInfo(data: readings)),
                                       query: query, filter: filter, favoriteIDs: favoriteIDs, lang: lang)
    }
}
