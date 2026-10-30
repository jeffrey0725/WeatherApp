import Foundation

struct MoonDay {
    let date: Date
    let moonrise: Date?
    let moonset: Date?
}

// HKO's MRS table lists the moonrise, moon transit and moonset of each Hong Kong date. The moon rises and
// sets about 50 minutes later every day, so a date can have no moonrise or no moonset, and the moonset can
// come before the moonrise. Unlike the sun's table the two events therefore have no ordering rule, and a
// blank cell means "no event on this date". Moon transit is not shown.
struct MoonTimesResponse: Decodable {
    let days: [MoonDay]
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
            return MoonDay(date: date,
                           moonrise: try HKOOpenDataTable.time(row[riseIndex], on: date),
                           moonset: try HKOOpenDataTable.time(row[setIndex], on: date))
        }
    }
}

struct MoonTimesSnapshot {
    struct Event {
        enum Kind { case moonrise, moonset }
        let kind: Kind
        let time: Date
    }

    let today: MoonDay
    let tomorrow: MoonDay?

    /// Tomorrow's row only counts when it is really the next Hong Kong date.
    var nextDay: MoonDay? {
        guard let tomorrow,
              let date = SolarDay.calendar.date(byAdding: .day, value: 1, to: today.date),
              tomorrow.date == date else { return nil }
        return tomorrow
    }

    /// The earliest known event after `now`. Only events beyond tomorrow are unknown and they are later
    /// than every known one, so no earlier event can be missed; nil when nothing known is left.
    func nextEvent(at now: Date) -> Event? {
        guard SolarDay.calendar.isDate(today.date, inSameDayAs: now) else { return nil }
        return (Self.events(of: today) + (nextDay.map(Self.events(of:)) ?? []))
            .filter { $0.time > now }
            .min { $0.time < $1.time }
    }

    private static func events(of day: MoonDay) -> [Event] {
        [day.moonrise.map { Event(kind: .moonrise, time: $0) },
         day.moonset.map { Event(kind: .moonset, time: $0) }].compactMap { $0 }
    }
}
