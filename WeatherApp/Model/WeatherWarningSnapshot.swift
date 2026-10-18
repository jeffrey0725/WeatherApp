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

    var emptyMessageKey: String {
        switch state {
        case .unavailable: return "weather_warning_status_unknown"
        case .current: return "weather_no_warnings"
        case .previous: return "weather_previous_no_warnings"
        }
    }

    func activeWarningKeys(at date: Date) -> [String] {
        guard let lastChecked else { return [] }
        // A failed refresh cannot establish today's warning status. Evaluate
        // retained warnings at the time their snapshot was successfully fetched.
        return report.activeWarningKeys(at: state == .previous ? lastChecked : date)
    }
}
