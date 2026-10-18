import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class RainfallMapTests: XCTestCase {
    func testVerifiedCatalogCoversEveryRainfallAliasWithHongKongCoordinates() {
        XCTAssertEqual(RainfallStationCatalog.locations.count, 36)
        XCTAssertEqual(Set(RainfallStationCatalog.locations.keys), Set(RainfallStationCatalog.names.keys))
        for location in RainfallStationCatalog.locations.values {
            XCTAssertTrue(location.latitude.isFinite && (22.1...22.6).contains(location.latitude))
            XCTAssertTrue(location.longitude.isFinite && (113.8...114.4).contains(location.longitude))
        }
    }

    func testSpatialIDsAreNotMistakenForAPIIDs() throws {
        // Spatial RF003 is Shui Pin Wai; its data_url identifies API N12.
        let shuiPinWai = try XCTUnwrap(RainfallStationCatalog.locations["N12"])
        XCTAssertEqual(shuiPinWai.latitude, 22.44614626, accuracy: 0.00000001)
        XCTAssertEqual(shuiPinWai.longitude, 114.02096340, accuracy: 0.00000001)
        // Spatial RF022 is Sha Tin; its data_url identifies API RF020.
        let shaTin = try XCTUnwrap(RainfallStationCatalog.locations["RF020"])
        XCTAssertEqual(shaTin.latitude, 22.40250000, accuracy: 0.00000001)
        XCTAssertEqual(shaTin.longitude, 114.21000000, accuracy: 0.00000001)
        let shamShuiPo = try XCTUnwrap(RainfallStationCatalog.locations["RF022"])
        XCTAssertEqual(shamShuiPo.latitude, 22.33583333, accuracy: 0.00000001)
    }

    func testAllNonRFStationsUseVerifiedRainfallPoints() throws {
        let expected: [(String, Double, Double)] = [
            ("N12", 22.44614626, 114.02096340), ("N15", 22.38261834, 114.27028350),
            ("K02", 22.34299050, 114.17892222), ("K09", 22.33257776, 114.19570500),
            ("K03", 22.31861151, 114.22461660), ("H17", 22.27173028, 114.16407860),
            ("H15", 22.21557006, 114.21565990), ("H24", 22.25126785, 114.17355890)
        ]
        for (id, latitude, longitude) in expected {
            let location = try XCTUnwrap(RainfallStationCatalog.locations[id])
            XCTAssertEqual(location.latitude, latitude, accuracy: 0.00000001, id)
            XCTAssertEqual(location.longitude, longitude, accuracy: 0.00000001, id)
        }
    }

    func testMapRetainsZeroMaintenanceAndUnavailableWithStableIDs() throws {
        let report = try decode([
            station("RF020", value: "0"), station("RF023", value: "M"),
            station("N12", value: "bad"), station("RF001", value: "9")
        ])
        let results = RainfallMapResults(report: report, query: "")
        XCTAssertEqual(Set(results.stations.map(\.id)), ["RF020", "RF023", "N12", "RF001"])
        XCTAssertTrue(results.unmapped.isEmpty)
        XCTAssertEqual(results.stations.first { $0.id == "RF020" }?.reading.status, .measured(0))
        XCTAssertEqual(results.stations.first { $0.id == "RF023" }?.reading.status, .maintenance)
        XCTAssertEqual(results.stations.first { $0.id == "N12" }?.reading.status, .unavailable)
        XCTAssertEqual(results.stations.map(\.id), results.ranked.map(\.id))
    }

    func testBilingualAndIDSearchFiltersMapAndRankingTogether() throws {
        let report = try decode([station("RF020", value: "4"), station("RF023", value: "8")])
        for query in ["Sha Tin", "  沙田  ", "rf020"] {
            let results = RainfallMapResults(report: report, query: query)
            XCTAssertEqual(results.ranked.map(\.id), ["RF020"])
            XCTAssertEqual(results.stations.map(\.id), ["RF020"])
            XCTAssertTrue(results.unmapped.isEmpty)
        }
    }

    func testUnknownFutureStationRemainsInRankingWithoutInventedCoordinates() throws {
        let report = try decode([station("NEW99", value: "30"), station("RF020", value: "4")])
        let results = RainfallMapResults(report: report, query: "")
        XCTAssertEqual(results.ranked.map(\.id), ["NEW99", "RF020"])
        XCTAssertEqual(results.stations.map(\.id), ["RF020"])
        XCTAssertEqual(results.unmapped.map(\.id), ["NEW99"])
        let unknownOnly = RainfallMapResults(report: report, query: "NEW99")
        XCTAssertTrue(unknownOnly.stations.isEmpty)
        XCTAssertEqual(unknownOnly.ranked.first?.amount, 30)
        XCTAssertEqual(unknownOnly.unmapped.count, 1)
    }

    func testEmptyReportAndUnmatchedQueryHaveNoMapPoints() throws {
        let empty = RainfallMapResults(report: try decode([]), query: "")
        XCTAssertTrue(empty.stations.isEmpty && empty.ranked.isEmpty && empty.unmapped.isEmpty)
        let unmatched = RainfallMapResults(report: try decode([station("RF020", value: "4")]), query: "No such station")
        XCTAssertTrue(unmatched.stations.isEmpty && unmatched.ranked.isEmpty && unmatched.unmapped.isEmpty)
    }

    func testSelectionPreservesReadingAndHourAcrossNewReportIncludingMidnight() throws {
        let first = try decode([station("RF020", value: "4")], time: "2026-10-18T00:30:00+08:00")
        let checked = Date(timeIntervalSince1970: 100)
        let selection = RainfallStationSelection(reading: try XCTUnwrap(first.readings.first), report: first,
                                                lastChecked: checked, wasUnconfirmed: false)
        let replacement = try decode([station("RF020", value: "9")], time: "2026-10-18T01:00:00+08:00")
        XCTAssertEqual(selection.id, "RF020")
        XCTAssertEqual(selection.reading.amount, 4)
        XCTAssertEqual(replacement.readings.first?.amount, 9)
        XCTAssertEqual(selection.observationPeriod, first.observationPeriod)
        XCTAssertNotEqual(selection.observationPeriod, replacement.observationPeriod)
        XCTAssertEqual(selection.observationPeriod.duration, 3600)
        XCTAssertEqual(selection.observationPeriod.start, ISO8601DateFormatter().date(from: "2026-10-17T23:30:00+08:00"))
    }

    func testSelectionLabelsPendingFailedAndReplacedSnapshotsAsPrevious() throws {
        let report = try decode([station("RF020", value: "4")])
        let reading = try XCTUnwrap(report.readings.first)
        let checked = Date(timeIntervalSince1970: 100)
        let selection = RainfallStationSelection(reading: reading, report: report,
                                                lastChecked: checked, wasUnconfirmed: false)
        XCTAssertFalse(selection.isPrevious(currentCheck: checked, isLoading: false, hasError: false))
        XCTAssertTrue(selection.isPrevious(currentCheck: checked, isLoading: true, hasError: false))
        XCTAssertTrue(selection.isPrevious(currentCheck: checked, isLoading: false, hasError: true))
        XCTAssertTrue(selection.isPrevious(currentCheck: checked.addingTimeInterval(1), isLoading: false, hasError: false))
        XCTAssertTrue(selection.isPrevious(currentCheck: nil, isLoading: false, hasError: false))
        let unconfirmed = RainfallStationSelection(reading: reading, report: report,
                                                  lastChecked: checked, wasUnconfirmed: true)
        XCTAssertTrue(unconfirmed.isPrevious(currentCheck: checked, isLoading: false, hasError: false))
    }

    func testMaintenanceAndUnknownSelectionsNeverBecomeZeroMeasurements() throws {
        let report = try decode([station("RF020", value: "M"), station("NEW99", value: "bad")])
        for reading in report.readings {
            let selection = RainfallStationSelection(reading: reading, report: report,
                                                    lastChecked: nil, wasUnconfirmed: true)
            XCTAssertNil(selection.reading.amount)
            XCTAssertEqual(selection.reading.status, reading.status)
            XCTAssertEqual(selection.observationPeriod, report.observationPeriod)
        }
    }

    func testReplacementReportKeepsMapIDsAndUpdatesValues() throws {
        let first = RainfallMapResults(report: try decode([station("RF020", value: "4")]), query: "")
        let second = RainfallMapResults(report: try decode([station("RF020", value: "0")]), query: "")
        XCTAssertEqual(first.stations.map(\.id), second.stations.map(\.id))
        XCTAssertEqual(first.stations.first?.reading.amount, 4)
        XCTAssertEqual(second.stations.first?.reading.amount, 0)
    }

    private func station(_ id: String, value: String) -> [String: String] {
        ["automaticWeatherStationID": id, "value": value, "unit": "mm"]
    }

    private func decode(_ stations: [[String: String]], time: String = "2026-10-18T08:00:00+08:00") throws -> HourlyRainfallReport {
        let data = try JSONSerialization.data(withJSONObject: ["obsTime": time, "hourlyRainfall": stations])
        return try JSONDecoder().decode(HourlyRainfallReport.self, from: data)
    }
}
