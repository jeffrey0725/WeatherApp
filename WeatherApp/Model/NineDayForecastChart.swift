import Foundation

struct NineDayForecastChartData {
    struct Day: Identifiable {
        let id: String
        let date: Date
        let forecast: WeatherForecast
        let lowCelsius: Int?
        let highCelsius: Int?
    }

    enum TemperatureKind: String, CaseIterable {
        case low, high
        var titleKey: String { self == .low ? "weather_low" : "weather_high" }
    }

    struct Point: Identifiable {
        var id: String { "\(dayID)-\(kind.rawValue)" }
        let dayID: String
        let date: Date
        let kind: TemperatureKind
        let celsius: Int
        let value: Double
        let seriesID: String
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return calendar
    }

    let days: [Day]
    let omittedDateCount: Int

    init(forecast: NineDayWeatherForecast) {
        let source = forecast.weatherForecast ?? []
        let dated: [Day] = source.compactMap { forecast in
            guard let key = forecast.forecastDate, let date = Self.date(key) else { return nil }
            var low = Self.celsius(forecast.forecastMintemp)
            var high = Self.celsius(forecast.forecastMaxtemp)
            if let minimum = low, let maximum = high, minimum > maximum {
                low = nil
                high = nil
            }
            return Day(id: key, date: date, forecast: forecast, lowCelsius: low, highCelsius: high)
        }
        // Conflicting duplicate dates have no unambiguous chart identity. Keep
        // the source records available in the full report instead of guessing.
        let counts = Dictionary(grouping: dated, by: \.id).mapValues(\.count)
        days = dated.filter { counts[$0.id] == 1 }.sorted { $0.date < $1.date }
        omittedDateCount = source.count - days.count
    }

    var hasUnavailableValues: Bool {
        omittedDateCount > 0 || days.contains { $0.lowCelsius == nil || $0.highCelsius == nil }
    }

    func selectedDay(id: String?) -> Day? {
        days.first { $0.id == id } ?? days.first
    }

    func nearestDay(to date: Date) -> Day? {
        days.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    func points(unit: TemperatureUnit) -> [Point] {
        TemperatureKind.allCases.flatMap { kind -> [Point] in
            var points: [Point] = []
            var previousDate: Date?
            var segment = 0
            for day in days {
                guard let celsius = kind == .low ? day.lowCelsius : day.highCelsius else {
                    previousDate = nil
                    segment += 1
                    continue
                }
                if let previousDate,
                   Self.calendar.date(byAdding: .day, value: 1, to: previousDate) != day.date {
                    segment += 1
                }
                let value = unit == .fahrenheit ? Double(celsius) * 9 / 5 + 32 : Double(celsius)
                points.append(Point(dayID: day.id, date: day.date, kind: kind, celsius: celsius,
                                    value: value, seriesID: "\(kind.rawValue)-\(segment)"))
                previousDate = day.date
            }
            return points
        }
    }

    private static func celsius(_ reading: ForecastValueWithUnit?) -> Int? {
        guard reading?.unit == "C" else { return nil }
        return reading?.value
    }

    private static func date(_ key: String) -> Date? {
        guard key.range(of: #"^[0-9]{8}$"#, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        formatter.isLenient = false
        guard let date = formatter.date(from: key), formatter.string(from: date) == key else { return nil }
        return date
    }
}
