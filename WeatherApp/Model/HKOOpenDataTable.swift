import Foundation

/// Strict parsing shared by HKO's `opendata.php` tables (sun, moon and tide data). Rows name a Hong Kong
/// calendar day and clock times, not full timestamps, so every value is resolved in Hong Kong time.
enum HKOOpenDataTable {
    enum TimeFormat {
        case colon      // 06:21, used by the sun and moon tables
        case compact    // 0621, used by the tide table

        fileprivate var pattern: String { self == .colon ? #"^\d{2}:\d{2}$"# : #"^\d{4}$"# }
    }

    /// The start of the Hong Kong day named by a `YYYY-MM-DD` key.
    static func day(_ key: String) throws -> Date {
        guard key.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            throw WeatherServiceError.invalidData
        }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw WeatherServiceError.invalidData }
        return try day(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Rejects dates that do not exist, such as 2026-02-30, instead of letting the calendar roll them over.
    static func day(year: Int, month: Int, day: Int) throws -> Date {
        let calendar = SolarDay.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { throw WeatherServiceError.invalidData }
        return date
    }

    /// A blank cell means the event does not happen on that date; any other malformed text is rejected.
    static func clock(_ raw: String?, format: TimeFormat = .colon) throws -> (hour: Int, minute: Int)? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard raw.range(of: format.pattern, options: .regularExpression) != nil else {
            throw WeatherServiceError.invalidData
        }
        let digits = raw.filter { $0 != ":" }
        guard let hour = Int(digits.prefix(2)), let minute = Int(digits.suffix(2)),
              (0...23).contains(hour), (0...59).contains(minute) else { throw WeatherServiceError.invalidData }
        return (hour, minute)
    }

    static func time(_ raw: String?, on date: Date, format: TimeFormat = .colon) throws -> Date? {
        guard let clock = try clock(raw, format: format) else { return nil }
        return try time(hour: clock.hour, minute: clock.minute, on: date)
    }

    static func time(hour: Int, minute: Int, on date: Date) throws -> Date {
        guard let time = SolarDay.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else {
            throw WeatherServiceError.invalidData
        }
        return time
    }
}
