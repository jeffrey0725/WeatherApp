import Foundation

struct TideReading {
    let time: Date
    let heightMeters: Double
}

struct TideDay {
    let date: Date
    let readings: [TideReading]
}

// HKO's HLT table has one row per date: Month, Date, then up to four Time/Height(m) pairs. The column names
// repeat, so the pairs are read by position. Dates with fewer tides have blank trailing cells. The row
// carries no year, so the service ties it to the Hong Kong date it asked for.
struct TideTimesResponse: Decodable {
    struct Row {
        let month: Int
        let day: Int
        let readings: [(hour: Int, minute: Int, height: Double)]

        /// Resolves the row to a Hong Kong calendar day. Heights are the predicted values HKO publishes.
        func tideDay(year: Int) throws -> TideDay {
            let date = try HKOOpenDataTable.day(year: year, month: month, day: day)
            return TideDay(date: date, readings: try readings.map {
                TideReading(time: try HKOOpenDataTable.time(hour: $0.hour, minute: $0.minute, on: date),
                            heightMeters: $0.height)
            })
        }
    }

    let rows: [Row]
    private enum CodingKeys: CodingKey { case fields, data }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fields = try container.decode([String].self, forKey: .fields)
        let table = try container.decode([[String?]].self, forKey: .data)
        guard fields.count >= 4, fields.count.isMultiple(of: 2), fields[0] == "Month", fields[1] == "Date",
              stride(from: 2, to: fields.count, by: 2).allSatisfy({ fields[$0] == "Time" && fields[$0 + 1] == "Height(m)" })
        else { throw WeatherServiceError.invalidData }
        var seen = Set<[Int]>()
        rows = try table.map { cells in
            guard cells.count == fields.count,
                  let month = cells[0].flatMap({ Int($0) }), let day = cells[1].flatMap({ Int($0) }),
                  (1...12).contains(month), (1...31).contains(day), seen.insert([month, day]).inserted
            else { throw WeatherServiceError.invalidData }
            var readings: [(hour: Int, minute: Int, height: Double)] = []
            for index in stride(from: 2, to: cells.count, by: 2) {
                let clock = try HKOOpenDataTable.clock(cells[index], format: .compact)
                let height = cells[index + 1].flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Double($0) }
                // A time needs a height and a height needs a time; both blank means no further tide.
                guard (clock == nil) == (height == nil) else { throw WeatherServiceError.invalidData }
                guard let clock, let height else { continue }
                guard height.isFinite else { throw WeatherServiceError.invalidData }
                if let last = readings.last, (last.hour, last.minute) >= (clock.hour, clock.minute) {
                    throw WeatherServiceError.invalidData
                }
                readings.append((clock.hour, clock.minute, height))
            }
            return Row(month: month, day: day, readings: readings)
        }
    }
}

struct TideEvent: Identifiable {
    enum Kind { case high, low }

    let time: Date
    let heightMeters: Double
    /// Nil when the neighbouring tides cannot say whether this one is a high or a low.
    let kind: Kind?
    var id: Date { time }
}

struct TideTimesSnapshot {
    let station: TideStation
    let today: TideDay
    let tomorrow: TideDay?

    /// Tomorrow's row only counts when it is really the next Hong Kong date.
    var nextDay: TideDay? {
        guard let tomorrow,
              let date = SolarDay.calendar.date(byAdding: .day, value: 1, to: today.date),
              tomorrow.date == date else { return nil }
        return tomorrow
    }

    /// The table does not say which tide is high, but extremes alternate, so a high tide is higher than
    /// its neighbours and a low tide lower. Neighbours come from today and tomorrow together, so the first
    /// and last tide of a day are still classified. Anything ambiguous stays unlabeled.
    var events: [TideEvent] {
        let readings = today.readings + (nextDay?.readings ?? [])
        return readings.indices.map { index in
            let height = readings[index].heightMeters
            let neighbours = [index - 1, index + 1].filter(readings.indices.contains).map { readings[$0].heightMeters }
            let kind: TideEvent.Kind? = neighbours.isEmpty ? nil
                : neighbours.allSatisfy { height > $0 } ? .high
                : neighbours.allSatisfy { height < $0 } ? .low : nil
            return TideEvent(time: readings[index].time, heightMeters: height, kind: kind)
        }
    }

    func events(on day: Date) -> [TideEvent] {
        events.filter { SolarDay.calendar.isDate($0.time, inSameDayAs: day) }
    }

    /// The first known tide after `now`; nil when today's table is not for the current Hong Kong date or
    /// no known tide is left (tides beyond tomorrow are not requested).
    func nextEvent(at now: Date) -> TideEvent? {
        guard SolarDay.calendar.isDate(today.date, inSameDayAs: now) else { return nil }
        return events.first { $0.time > now }
    }
}

enum TideFormatting {
    static func height(_ meters: Double, locale: Locale) -> String {
        meters.formatted(.number.precision(.fractionLength(2)).locale(locale))
    }
}
