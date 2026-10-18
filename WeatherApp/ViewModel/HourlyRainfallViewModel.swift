import Foundation
import Combine

@MainActor
final class HourlyRainfallViewModel: ObservableObject {
    @Published private(set) var section = WeatherDashboardSection<HourlyRainfallReport>()
    private let service: WeatherService
    private let requests = WeatherRequestCoordinator()
    private var contentLanguage: String?

    init(service: WeatherService = WeatherService()) { self.service = service }

    func refresh(lang: String) async {
        await requests.perform(language: lang) {
            if self.contentLanguage != lang {
                self.section = WeatherDashboardSection()
                self.contentLanguage = lang
            }
            self.section.isLoading = true
            self.section.errorMessage = nil
            defer { self.section.isLoading = false }
            do {
                let report = try await self.service.hourlyRainfall(lang: lang)
                try Task.checkCancellation()
                self.section.value = report
                self.section.lastChecked = Date()
            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch {
                self.section.errorMessage = WeatherServiceError.message(for: error, lang: lang)
            }
        }
    }
}
