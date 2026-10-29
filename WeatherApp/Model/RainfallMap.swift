import Foundation

struct RainfallMapStation: Identifiable {
    let reading: HourlyRainfallReading
    let location: RainfallStationCatalog.Location
    var id: String { reading.id }
}

struct RainfallMapResults {
    let ranked: [HourlyRainfallReading]
    let stations: [RainfallMapStation]
    let unmapped: [HourlyRainfallReading]

    init(report: HourlyRainfallReport, query: String) {
        ranked = report.rankedStations(matching: query)
        stations = ranked.compactMap { reading in
            guard let location = RainfallStationCatalog.locations[reading.id] else { return nil }
            return RainfallMapStation(reading: reading, location: location)
        }
        unmapped = ranked.filter { RainfallStationCatalog.locations[$0.id] == nil }
    }
}

/// How rainfall pins are drawn. At the default zoom the whole territory is visible and the full
/// "0 mm" capsules cover each other, so zoomed-out maps use small value-only pins.
enum RainfallMarkerStyle {
    /// Visible latitude span (degrees) above which pins are compact; Hong Kong is about 0.35 tall.
    static let compactLatitudeSpan = 0.12

    static func isCompact(latitudeSpan: Double) -> Bool { latitudeSpan > compactLatitudeSpan }

    /// Value without the unit; maintenance and unavailable keep their symbols.
    static func compactText(for status: HourlyRainfallReading.Status) -> String {
        switch status {
        case .measured(let amount): return String(amount)
        case .maintenance: return "M"
        case .unavailable: return "—"
        }
    }
}

// Capture the reading and observation interval together. Refreshes never change
// the content beneath an open sheet, including a maintenance/unavailable selection.
struct RainfallStationSelection: Identifiable {
    let reading: HourlyRainfallReading
    let observationPeriod: DateInterval
    let lastChecked: Date?
    let wasUnconfirmed: Bool
    var id: String { reading.id }

    init(reading: HourlyRainfallReading, report: HourlyRainfallReport,
         lastChecked: Date?, wasUnconfirmed: Bool) {
        self.reading = reading
        observationPeriod = report.observationPeriod
        self.lastChecked = lastChecked
        self.wasUnconfirmed = wasUnconfirmed
    }

    func isPrevious(currentCheck: Date?, isLoading: Bool, hasError: Bool) -> Bool {
        wasUnconfirmed || isLoading || hasError || lastChecked != currentCheck
    }
}
