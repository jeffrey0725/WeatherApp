import Foundation
import SwiftData
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class FavoriteStationTests: XCTestCase {
    func testStationIDsAreUniqueAndResolveInBothLanguages() {
        let stations = StationCoordinateStore.stationCoordinates
        XCTAssertEqual(Set(stations.map(\.id)).count, stations.count)
        XCTAssertFalse(stations.contains { $0.id.isEmpty })
        let station = StationCoordinateStore.station(withID: "sha-tin")
        XCTAssertEqual(station?.name(lang: "en"), "Sha Tin")
        XCTAssertEqual(station?.name(lang: "tc"), "沙田")
        XCTAssertNil(StationCoordinateStore.station(withID: "unknown-station"))
    }

    func testStationSearchMatchesBothLanguagesAndTrimsWhitespace() {
        XCTAssertEqual(StationCoordinateStore.stations(matching: "  sha tin  ", lang: "tc").map(\.id), ["sha-tin"])
        XCTAssertEqual(StationCoordinateStore.stations(matching: "沙田", lang: "en").map(\.id), ["sha-tin"])
        XCTAssertEqual(StationCoordinateStore.stations(matching: "", lang: "en").count, 27)
        XCTAssertTrue(StationCoordinateStore.stations(matching: "nonexistent", lang: "tc").isEmpty)
    }

    func testFavoriteMatchesTemperatureByStationInBothLanguages() throws {
        let station = try XCTUnwrap(StationCoordinateStore.station(withID: "sha-tin"))
        for place in ["Sha Tin", "沙田"] {
            let report = RegionWeatherForecast(temperature: TemperatureInfo(data: [
                TemperatureData(place: "Hong Kong Observatory", unit: "C", value: 28),
                TemperatureData(place: place, unit: "C", value: 25)
            ]))
            XCTAssertEqual(station.temperature(in: report)?.value, 25)
        }
        let missing = RegionWeatherForecast(temperature: TemperatureInfo(data: [
            TemperatureData(place: "Hong Kong Observatory", unit: "C", value: 28)
        ]))
        XCTAssertNil(station.temperature(in: missing))
        XCTAssertNil(station.temperature(in: nil))
    }

    func testDuplicateFavoritePreservesItsLabelAndOrder() {
        withStore { store in
            try store.add(stationID: "sha-tin", label: "  Home  ")
            try store.add(stationID: "tai-po", label: "Work")
            try store.add(stationID: "sha-tin", label: "Replacement")
            let saved = try store.favorites()
            XCTAssertEqual(saved.map(\.stationID), ["sha-tin", "tai-po"])
            XCTAssertEqual(saved.map(\.sortOrder), [0, 1])
            XCTAssertEqual(saved.first?.label, "Home")
            XCTAssertFalse(store.context.hasChanges)
        }
    }

    func testFavoriteLabelCanBeChangedOrCleared() {
        withStore { store in
            try store.add(stationID: "sha-tin", label: "Home")
            try store.updateLabel(stationID: "sha-tin", label: "  住所\n")
            XCTAssertEqual(try store.favorites().first?.label, "住所")
            try store.updateLabel(stationID: "sha-tin", label: "   ")
            XCTAssertEqual(try store.favorites().first?.label, "")
            XCTAssertEqual(try store.favorites().first?.stationID, "sha-tin")
        }
    }

    func testReorderingAndDeletingMaintainContiguousDisplayOrder() {
        withStore { store in
            for id in ["sha-tin", "tai-po", "tuen-mun", "tsing-yi"] { try store.add(stationID: id) }
            try store.move(from: IndexSet([0, 2]), to: 4)
            XCTAssertEqual(try store.favorites().map(\.stationID), ["tai-po", "tsing-yi", "sha-tin", "tuen-mun"])
            try store.move(from: IndexSet(integer: 3), to: 0)
            XCTAssertEqual(try store.favorites().map(\.stationID), ["tuen-mun", "tai-po", "tsing-yi", "sha-tin"])
            try store.remove(stationIDs: ["tai-po", "sha-tin"])
            XCTAssertEqual(try store.favorites().map(\.stationID), ["tuen-mun", "tsing-yi"])
            XCTAssertEqual(try store.favorites().map(\.sortOrder), [0, 1])
            try store.add(stationID: "sha-tin")
            XCTAssertEqual(try store.favorites().map(\.sortOrder), [0, 1, 2])
        }
    }

    func testInvalidStationOrMoveLeavesFavoritesUnchanged() {
        withStore { store in
            try store.add(stationID: "sha-tin", label: "Home")
            XCTAssertThrowsError(try store.add(stationID: "unknown"))
            XCTAssertThrowsError(try store.updateLabel(stationID: "unknown", label: "Work"))
            XCTAssertThrowsError(try store.move(from: IndexSet(integer: 9), to: 0))
            XCTAssertThrowsError(try store.move(from: IndexSet(integer: 0), to: -1))
            XCTAssertEqual(try store.favorites().map(\.stationID), ["sha-tin"])
            XCTAssertEqual(try store.favorites().first?.label, "Home")
            XCTAssertFalse(store.context.hasChanges)
        }
    }

    func testFailedSavesRollbackInsertUpdateDeleteAndReorder() {
        withStore { store in
            try store.add(stationID: "sha-tin", label: "Home")
            try store.add(stationID: "tai-po", label: "Work")
            let failing = FavoriteStationStore(context: store.context) { _ in throw TestSaveError.failure }

            XCTAssertThrowsError(try failing.add(stationID: "tuen-mun"))
            XCTAssertThrowsError(try failing.updateLabel(stationID: "sha-tin", label: "Changed"))
            XCTAssertThrowsError(try failing.remove(stationIDs: ["sha-tin"]))
            XCTAssertThrowsError(try failing.move(from: IndexSet(integer: 0), to: 2))
            let saved = try store.favorites()
            XCTAssertEqual(saved.map(\.stationID), ["sha-tin", "tai-po"])
            XCTAssertEqual(saved.map(\.label), ["Home", "Work"])
            XCTAssertEqual(saved.map(\.sortOrder), [0, 1])
            XCTAssertFalse(store.context.hasChanges)
        }
    }

    func testFavoritesPersistAfterReopeningDiskStore() {
        onMainActor {
            let directory = try Self.storeDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("favorites.store")
            try autoreleasepool {
                let container = try FavoritesPersistence.makeContainer(storeURL: url)
                let store = FavoriteStationStore(context: container.mainContext)
                try store.add(stationID: "sha-tin", label: "Home")
                try store.add(stationID: "tai-po", label: "Work")
                try store.add(stationID: "tuen-mun")
                try store.updateLabel(stationID: "sha-tin", label: "住所")
                try store.move(from: IndexSet(integer: 1), to: 0)
                try store.remove(stationIDs: ["tuen-mun"])
            }
            let reopened = try FavoritesPersistence.makeContainer(storeURL: url)
            let saved = try FavoriteStationStore(context: reopened.mainContext).favorites()
            XCTAssertEqual(saved.map(\.stationID), ["tai-po", "sha-tin"])
            XCTAssertEqual(saved.map(\.label), ["Work", "住所"])
            XCTAssertEqual(saved.map(\.sortOrder), [0, 1])
        }
    }

    private enum TestSaveError: Error { case failure }

    private func withStore(_ operation: @escaping @MainActor (FavoriteStationStore) throws -> Void) {
        onMainActor {
            let container = try FavoritesPersistence.makeContainer(inMemory: true)
            try operation(FavoriteStationStore(context: container.mainContext))
        }
    }

    private func onMainActor(_ operation: @escaping @MainActor () throws -> Void) {
        let completed = expectation(description: "Favorites operation completes")
        Task { @MainActor in
            do { try operation() }
            catch { XCTFail("Unexpected persistence error: \(error)") }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }

    private static func storeDirectory() throws -> URL {
        let root: URL
        if let path = ProcessInfo.processInfo.environment["WEATHERAPP_TEST_STORE_DIRECTORY"] {
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            // XCTest on a device uses that app's temporary container. The local
            // validation script always supplies a directory inside the project.
            root = FileManager.default.temporaryDirectory
        }
        let directory = root.appendingPathComponent("FavoriteStationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
