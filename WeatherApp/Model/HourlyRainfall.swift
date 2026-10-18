import Foundation

struct HourlyRainfallReport: Decodable {
    let observationTime: Date
    let readings: [HourlyRainfallReading]

    var observationPeriod: DateInterval {
        DateInterval(start: observationTime.addingTimeInterval(-3600), end: observationTime)
    }

    func rankedStations(matching query: String) -> [HourlyRainfallReading] {
        readings.filter { $0.matches(query) }.sorted {
            switch ($0.amount, $1.amount) {
            case let (.some(left), .some(right)) where left != right: return left > right
            case (.some, .none): return true
            case (.none, .some): return false
            default:
                let comparison = ($0.stationName ?? $0.id).localizedStandardCompare($1.stationName ?? $1.id)
                return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
            }
        }
    }

    enum CodingKeys: String, CodingKey { case obsTime, hourlyRainfall }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .obsTime)
        let formatter = ISO8601DateFormatter()
        var date = formatter.date(from: text)
        if date == nil {
            formatter.formatOptions.insert(.withFractionalSeconds)
            date = formatter.date(from: text)
        }
        guard let date else {
            throw DecodingError.dataCorruptedError(forKey: .obsTime, in: container,
                                                   debugDescription: "Invalid rainfall observation time")
        }
        observationTime = date
        readings = try container.decode([HourlyRainfallReading].self, forKey: .hourlyRainfall)
        guard Set(readings.map(\.id)).count == readings.count else {
            throw DecodingError.dataCorruptedError(forKey: .hourlyRainfall, in: container,
                                                   debugDescription: "Duplicate rainfall station IDs")
        }
    }
}

struct HourlyRainfallReading: Decodable, Identifiable {
    enum Status: Equatable {
        case measured(Int)
        case maintenance
        case unavailable
    }

    let id: String
    let stationName: String?
    let rawValue: String?
    let unit: String?

    var status: Status {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        if value?.uppercased() == "M" || unit?.uppercased() == "M" { return .maintenance }
        guard unit?.lowercased() == "mm", let value, let amount = Int(value), amount >= 0 else {
            return .unavailable
        }
        return .measured(amount)
    }

    var amount: Int? {
        if case .measured(let amount) = status { return amount }
        return nil
    }

    func name(lang: String) -> String {
        if let stationName, !stationName.isEmpty { return stationName }
        guard let names = RainfallStationCatalog.names[id] else { return id }
        return lang == "en" ? names.english : names.chinese
    }

    func matches(_ query: String) -> Bool {
        let query = Self.searchText(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else { return true }
        let aliases = RainfallStationCatalog.names[id]
        return [id, stationName, aliases?.english, aliases?.chinese].compactMap { $0 }
            .contains { Self.searchText($0).localizedStandardContains(query) }
    }

    private static func searchText(_ text: String) -> String {
        text.replacingOccurrences(of: "’", with: "'")
    }

    enum CodingKeys: String, CodingKey {
        case id = "automaticWeatherStationID"
        case stationName = "automaticWeatherStation"
        case rawValue = "value"
        case unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Empty rainfall station ID")
        }
        stationName = (try? container.decode(String.self, forKey: .stationName))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        unit = try? container.decode(String.self, forKey: .unit)
        if let value = try? container.decode(String.self, forKey: .rawValue) {
            rawValue = value
        } else if let value = try? container.decode(Int.self, forKey: .rawValue) {
            rawValue = String(value)
        } else {
            rawValue = nil
        }
    }
}

extension HourlyRainfallReading {
    @MainActor
    func displayText(settings: AppSettings) -> String {
        switch status {
        case .measured(let amount): return settings.measurement(amount, unit: "mm")
        case .maintenance: return settings.text("rainfall_maintenance")
        case .unavailable: return settings.text("weather_unavailable")
        }
    }
}
