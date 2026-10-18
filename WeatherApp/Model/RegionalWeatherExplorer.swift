import Foundation

enum RegionalStationFilter: String, CaseIterable, Identifiable {
    case all
    case favorites

    var id: String { rawValue }
    var titleKey: String { self == .all ? "explorer_all_stations" : "favorites_title" }
}

enum RegionalExplorerDisplayMode: String, CaseIterable, Identifiable {
    case map, list
    var id: String { rawValue }
    var titleKey: String { self == .map ? "explorer_map" : "explorer_list" }
}

enum RegionalStationSort: String, CaseIterable, Identifiable {
    case name, warmest, coolest
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .name: return "explorer_sort_name"
        case .warmest: return "explorer_sort_warmest"
        case .coolest: return "explorer_sort_coolest"
        }
    }
}

struct RegionalStationSelection: Identifiable {
    let id: String
    let station: TemperatureData
    let observationTime: String?
}

struct RegionalStationObservation: Identifiable {
    let station: StationCoordinate
    let reading: TemperatureData?

    var id: String { station.id }

    // HKO reports these station temperatures in Celsius. Unknown units can be
    // displayed as supplied, but must not be ranked against Celsius values.
    var temperatureForSorting: Int? { reading?.unit == "C" ? reading?.value : nil }

    func selection(lang: String, observationTime: String?) -> RegionalStationSelection {
        var details = reading ?? TemperatureData()
        details.place = station.name(lang: lang)
        details.latitude = station.coordinate.latitude
        details.longitude = station.coordinate.longitude
        return RegionalStationSelection(id: id, station: details,
                                        observationTime: details.value == nil ? nil : observationTime)
    }

    func mapReading(lang: String) -> TemperatureData? {
        guard reading?.value != nil else { return nil }
        return selection(lang: lang, observationTime: nil).station
    }
}

struct RegionalWeatherExplorerResults {
    let stations: [RegionalStationObservation]

    init(report: RegionWeatherForecast, query: String, filter: RegionalStationFilter,
         favoriteIDs: Set<String>, lang: String) {
        stations = StationCoordinateStore.stations(matching: query, lang: lang)
            .filter { filter == .all || favoriteIDs.contains($0.id) }
            .map { RegionalStationObservation(station: $0, reading: $0.temperature(in: report)) }
    }

    var unavailableCount: Int { stations.filter { $0.reading?.value == nil }.count }

    func mapReadings(lang: String) -> [TemperatureData] {
        stations.compactMap { $0.mapReading(lang: lang) }
    }

    func listStations(sort: RegionalStationSort, lang: String) -> [RegionalStationObservation] {
        stations.sorted { first, second in
            if sort != .name {
                switch (first.temperatureForSorting, second.temperatureForSorting) {
                case let (left?, right?) where left != right:
                    return sort == .warmest ? left > right : left < right
                case (_?, nil): return true
                case (nil, _?): return false
                default: break
                }
            }
            let order = first.station.name(lang: lang).compare(second.station.name(lang: lang),
                options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: AppLanguage.forAPI(lang).locale)
            return order == .orderedSame ? first.id < second.id : order == .orderedAscending
        }
    }
}
