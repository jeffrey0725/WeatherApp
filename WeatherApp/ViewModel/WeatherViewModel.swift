import Foundation
import Combine
import CoreLocation

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published private(set) var localWeatherForecast = LocalWeatherForecast()
    @Published private(set) var nineDayWeatherForecast = NineDayWeatherForecast()
    @Published private(set) var regionWeatherForecast = RegionWeatherForecast()
    @Published private(set) var warningReport = WeatherWarningReport()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastChecked: Date?

    private let service: WeatherService
    private let requests = WeatherRequestCoordinator()
    private var contentLanguage: String?

    init(service: WeatherService = WeatherService()) {
        self.service = service
    }

    func loadLocalForecast(lang: String) async {
        await load(lang: lang, fetch: { try await self.service.localForecast(lang: lang) }) {
            self.localWeatherForecast = $0
        }
    }

    func loadNineDayForecast(lang: String) async {
        await load(lang: lang, fetch: { try await self.service.nineDayForecast(lang: lang) }) {
            self.nineDayWeatherForecast = $0
        }
    }

    func loadCurrentReport(lang: String) async {
        await load(lang: lang, fetch: {
            var report = try await self.service.currentReport(lang: lang)
            let coordinates = Dictionary(uniqueKeysWithValues:
                StationCoordinateStore.stationCoordinates.flatMap { station in
                    [(station.placeTC, station.coordinate), (station.placeEN, station.coordinate)]
                })
            if var stations = report.temperature?.data {
                for index in stations.indices {
                    if let coordinate = coordinates[stations[index].place ?? ""] {
                        stations[index].latitude = coordinate.latitude
                        stations[index].longitude = coordinate.longitude
                    }
                }
                report.temperature?.data = stations
            }
            return report
        }) {
            self.regionWeatherForecast = $0
        }
    }

    func loadWarnings(lang: String) async {
        await load(lang: lang, fetch: { try await self.service.warningReport(lang: lang) }) {
            self.warningReport = $0
        }
    }

    private func load<Value>(lang: String, fetch: @escaping @MainActor () async throws -> Value,
                             apply: @escaping @MainActor (Value) -> Void) async {
        await requests.perform(language: lang) {
            if self.contentLanguage != lang {
                self.localWeatherForecast = LocalWeatherForecast()
                self.nineDayWeatherForecast = NineDayWeatherForecast()
                self.regionWeatherForecast = RegionWeatherForecast()
                self.warningReport = WeatherWarningReport()
                self.lastChecked = nil
                self.contentLanguage = lang
            }
            self.isLoading = true
            self.errorMessage = nil
            defer { self.isLoading = false }
            do {
                let value = try await fetch()
                try Task.checkCancellation()
                apply(value)
                self.lastChecked = Date()
            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch {
                self.errorMessage = WeatherServiceError.message(for: error, lang: lang)
            }
        }
    }
}
