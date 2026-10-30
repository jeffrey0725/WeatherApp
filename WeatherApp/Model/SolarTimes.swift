import Foundation

struct SolarDay {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return calendar
    }

    let date: Date
    let sunrise: Date?
    let sunset: Date?

    var daylightDuration: TimeInterval? {
        guard let sunrise, let sunset else { return nil }
        return sunset.timeIntervalSince(sunrise)
    }

    func daylightProgress(at now: Date) -> Double? {
        guard Self.calendar.isDate(date, inSameDayAs: now),
              let sunrise, let duration = daylightDuration, duration > 0 else { return nil }
        return min(1, max(0, now.timeIntervalSince(sunrise) / duration))
    }
}

// HKO's SRS JSON is a table, not a keyed weather.php response. Resolve columns
// by their documented names so a reordered or additional column stays safe.
struct SolarTimesResponse: Decodable {
    let days: [SolarDay]
    private enum CodingKeys: CodingKey { case fields, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fields = try container.decode([String].self, forKey: .fields)
        let rows = try container.decode([[String?]].self, forKey: .data)
        guard Set(fields).count == fields.count,
              let dateIndex = fields.firstIndex(of: "YYYY-MM-DD"),
              let riseIndex = fields.firstIndex(of: "RISE"),
              let setIndex = fields.firstIndex(of: "SET") else {
            throw WeatherServiceError.invalidData
        }
        var dates = Set<Date>()
        days = try rows.map { row in
            guard row.count == fields.count, let key = row[dateIndex] else { throw WeatherServiceError.invalidData }
            let date = try HKOOpenDataTable.day(key)
            guard dates.insert(date).inserted else { throw WeatherServiceError.invalidData }
            let sunrise = try HKOOpenDataTable.time(row[riseIndex], on: date)
            let sunset = try HKOOpenDataTable.time(row[setIndex], on: date)
            if let sunrise, let sunset, sunrise >= sunset { throw WeatherServiceError.invalidData }
            return SolarDay(date: date, sunrise: sunrise, sunset: sunset)
        }
    }
}

struct SolarTimesSnapshot {
    struct Event {
        enum Kind { case sunrise, sunset }
        let kind: Kind
        let time: Date
    }
    let today: SolarDay
    let tomorrow: SolarDay?

    func nextEvent(at now: Date) -> Event? {
        guard SolarDay.calendar.isDate(today.date, inSameDayAs: now),
              let sunrise = today.sunrise, let sunset = today.sunset else { return nil }
        if now < sunrise { return Event(kind: .sunrise, time: sunrise) }
        if now < sunset { return Event(kind: .sunset, time: sunset) }
        guard let tomorrow, let nextDate = SolarDay.calendar.date(byAdding: .day, value: 1, to: today.date),
              tomorrow.date == nextDate, let rise = tomorrow.sunrise else { return nil }
        return Event(kind: .sunrise, time: rise)
    }
}

enum SolarTimesFormatting {
    static func time(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = SolarDay.calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func date(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = SolarDay.calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func duration(_ interval: TimeInterval, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = SolarDay.calendar
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        // Keep a future event at least one minute away in a minute-resolution UI.
        return formatter.string(from: max(0, ceil(interval / 60) * 60)) ?? "—"
    }
}
