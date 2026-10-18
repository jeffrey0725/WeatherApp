import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class WeatherWarningSnapshotTests: XCTestCase {
    private let checked = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoSuccessfulSnapshotCannotReportNoActiveWarnings() {
        let snapshot = WeatherWarningSnapshot(report: WeatherWarningReport(), lastChecked: nil,
                                              isRefreshing: false, hasError: true)
        XCTAssertEqual(snapshot.state, .unavailable)
        XCTAssertEqual(snapshot.emptyMessageKey, "weather_warning_status_unknown")
        XCTAssertTrue(snapshot.activeWarningKeys(at: checked).isEmpty)
    }

    func testFailedRefreshKeepsWarningActiveAtItsOriginalCheckTime() {
        let snapshot = snapshot(isRefreshing: false, hasError: true)
        XCTAssertEqual(snapshot.state, .previous)
        XCTAssertEqual(snapshot.activeWarningKeys(at: checked.addingTimeInterval(7200)), ["WTS"])
        XCTAssertEqual(snapshot.emptyMessageKey, "weather_previous_no_warnings")
    }

    func testRefreshingRetainedReportIsAlsoPrevious() {
        let snapshot = snapshot(isRefreshing: true, hasError: false)
        XCTAssertEqual(snapshot.state, .previous)
        XCTAssertEqual(snapshot.activeWarningKeys(at: checked.addingTimeInterval(7200)), ["WTS"])
    }

    func testFreshSnapshotExpiresWarningsAgainstCurrentTime() {
        let snapshot = snapshot(isRefreshing: false, hasError: false)
        XCTAssertEqual(snapshot.state, .current)
        XCTAssertEqual(snapshot.activeWarningKeys(at: checked), ["WTS"])
        XCTAssertTrue(snapshot.activeWarningKeys(at: checked.addingTimeInterval(7200)).isEmpty)
        XCTAssertEqual(snapshot.emptyMessageKey, "weather_no_warnings")
    }

    func testPreviousEmptyReportHasHistoricalEmptyMessage() {
        let snapshot = WeatherWarningSnapshot(report: WeatherWarningReport(), lastChecked: checked,
                                              isRefreshing: false, hasError: true)
        XCTAssertEqual(snapshot.state, .previous)
        XCTAssertTrue(snapshot.activeWarningKeys(at: checked.addingTimeInterval(7200)).isEmpty)
        XCTAssertNotEqual(snapshot.emptyMessageKey, "weather_no_warnings")
    }

    func testReportWithoutCheckTimeIsUnavailableEvenIfItContainsWarnings() {
        let snapshot = WeatherWarningSnapshot(report: report, lastChecked: nil,
                                              isRefreshing: true, hasError: false)
        XCTAssertEqual(snapshot.state, .unavailable)
        XCTAssertTrue(snapshot.activeWarningKeys(at: checked).isEmpty)
    }

    private var report: WeatherWarningReport {
        let expiry = ISO8601DateFormatter().string(from: checked.addingTimeInterval(3600))
        return WeatherWarningReport(summary: ["WTS": WeatherWarning(code: "WTS", actionCode: "ISSUE", expireTime: expiry)])
    }

    private func snapshot(isRefreshing: Bool, hasError: Bool) -> WeatherWarningSnapshot {
        WeatherWarningSnapshot(report: report, lastChecked: checked,
                               isRefreshing: isRefreshing, hasError: hasError)
    }
}
