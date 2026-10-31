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

    func testEmptySummaryIsNotAnAllClearWhileStatementsAreMissing() {
        // Pre-No. 8 announcements come from the statements, so a quiet summary alone proves nothing.
        var partial = WeatherWarningReport()
        partial.missingParts = [.information]
        let current = WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: false)
        XCTAssertEqual(current.state, .current)
        XCTAssertEqual(current.emptyMessageKey, "weather_warning_partial_empty")
        let previous = WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: true)
        XCTAssertEqual(previous.state, .previous)
        XCTAssertEqual(previous.emptyMessageKey, "weather_previous_partial_empty")
        let unconfirmed = WeatherWarningSnapshot(report: partial, lastChecked: nil, isRefreshing: false, hasError: true)
        XCTAssertEqual(unconfirmed.emptyMessageKey, "weather_warning_status_unknown")
    }

    func testMissingTipsDoNotChangeWhatTheSummaryReports() {
        var partial = WeatherWarningReport()
        partial.missingParts = [.tips]
        XCTAssertEqual(WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: false).emptyMessageKey,
                       "weather_no_warnings")
        XCTAssertEqual(WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: true).emptyMessageKey,
                       "weather_previous_no_warnings")
        partial.missingParts = [.information, .tips]
        XCTAssertEqual(WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: false).emptyMessageKey,
                       "weather_warning_partial_empty")
    }

    func testPartialReportStillExpiresActiveWarningsLikeAnyOtherReport() {
        var partial = report
        partial.missingParts = [.information, .tips]
        let current = WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: false)
        XCTAssertEqual(current.activeWarningKeys(at: checked), ["WTS"])
        XCTAssertTrue(current.activeWarningKeys(at: checked.addingTimeInterval(7200)).isEmpty)
        let previous = WeatherWarningSnapshot(report: partial, lastChecked: checked, isRefreshing: false, hasError: true)
        XCTAssertEqual(previous.activeWarningKeys(at: checked.addingTimeInterval(7200)), ["WTS"])
    }

    func testPartialWarningStringsExistInBothLanguages() {
        let keys = ["weather_warning_partial_details", "weather_warning_partial_tips", "weather_warning_partial_empty",
                    "weather_previous_partial_empty", "weather_warning_details_unavailable"]
        for locale in [Locale(identifier: "en_HK"), Locale(identifier: "zh_Hant_HK")] {
            for key in keys {
                XCTAssertNotEqual(AppLocalization.text(key, locale: locale, bundle: Bundle(for: Self.self)), key,
                                  "\(key) missing for \(locale.identifier)")
            }
        }
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
