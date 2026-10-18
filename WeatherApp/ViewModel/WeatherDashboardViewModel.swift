import Foundation
import Combine

struct WeatherDashboardSection<Value> {
    var value: Value?
    var isLoading = false
    var errorMessage: String?
    var lastChecked: Date?
}

@MainActor
final class WeatherDashboardViewModel: ObservableObject {
    @Published private(set) var current = WeatherDashboardSection<RegionWeatherForecast>()
    @Published private(set) var local = WeatherDashboardSection<LocalWeatherForecast>()
    @Published private(set) var forecast = WeatherDashboardSection<NineDayWeatherForecast>()
    @Published private(set) var warnings = WeatherDashboardSection<WeatherWarningReport>()
    @Published private(set) var isLoading = false

    private let service: WeatherService
    private let requests = WeatherRequestCoordinator()
    private var contentLanguage: String?

    init(service: WeatherService = WeatherService()) {
        self.service = service
    }

    func refresh(lang: String) async {
        await requests.perform(language: lang) {
            if self.contentLanguage != lang {
                self.current = WeatherDashboardSection()
                self.local = WeatherDashboardSection()
                self.forecast = WeatherDashboardSection()
                self.warnings = WeatherDashboardSection()
                self.contentLanguage = lang
            }
            self.isLoading = true
            defer { self.isLoading = false }
            async let current: Void = self.loadCurrent(lang: lang)
            async let local: Void = self.loadLocal(lang: lang)
            async let forecast: Void = self.loadForecast(lang: lang)
            async let warnings: Void = self.loadWarnings(lang: lang)
            _ = await (current, local, forecast, warnings)
        }
    }

    private func loadCurrent(lang: String) async {
        await load(\.current, lang: lang) { try await self.service.currentReport(lang: lang) }
    }

    private func loadLocal(lang: String) async {
        await load(\.local, lang: lang) { try await self.service.localForecast(lang: lang) }
    }

    private func loadForecast(lang: String) async {
        await load(\.forecast, lang: lang) { try await self.service.nineDayForecast(lang: lang) }
    }

    private func loadWarnings(lang: String) async {
        await load(\.warnings, lang: lang) { try await self.service.warningReport(lang: lang) }
    }

    private func load<Value>(
        _ keyPath: ReferenceWritableKeyPath<WeatherDashboardViewModel, WeatherDashboardSection<Value>>,
        lang: String,
        operation: () async throws -> Value
    ) async {
        self[keyPath: keyPath].isLoading = true
        self[keyPath: keyPath].errorMessage = nil
        defer { self[keyPath: keyPath].isLoading = false }
        do {
            let value = try await operation()
            try Task.checkCancellation()
            self[keyPath: keyPath].value = value
            self[keyPath: keyPath].lastChecked = Date()
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            self[keyPath: keyPath].errorMessage = WeatherServiceError.message(for: error, lang: lang)
        }
    }
}
