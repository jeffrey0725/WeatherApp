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
