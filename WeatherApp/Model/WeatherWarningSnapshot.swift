import Foundation

struct WeatherWarningSnapshot {
    enum State: Equatable {
        case unavailable
        case current
        case previous
    }

    let report: WeatherWarningReport
    let lastChecked: Date?
    let isRefreshing: Bool
    let hasError: Bool

    var state: State {
        guard lastChecked != nil else { return .unavailable }
        return isRefreshing || hasError ? .previous : .current
    }

    // Pre-No. 8 announcements come from the statements, not the summary, so without them an empty summary
    // cannot be called an all-clear. Missing special tips do not change what the summary says.
    var emptyMessageKey: String {
        let announcementsMissing = report.missingParts.contains(.information)
        switch state {
        case .unavailable: return "weather_warning_status_unknown"
        case .current: return announcementsMissing ? "weather_warning_partial_empty" : "weather_no_warnings"
        case .previous: return announcementsMissing ? "weather_previous_partial_empty" : "weather_previous_no_warnings"
        }
    }

    func activeWarningKeys(at date: Date) -> [String] {
        guard let lastChecked else { return [] }
        // A failed refresh cannot establish today's warning status. Evaluate
        // retained warnings at the time their snapshot was successfully fetched.
        return report.activeWarningKeys(at: state == .previous ? lastChecked : date)
    }
}
