import Foundation
import Combine

@MainActor
final class SolarTimesViewModel: ObservableObject {
    @Published private(set) var section = WeatherDashboardSection<SolarTimesSnapshot>()
    private let service: WeatherService
    private let now: () -> Date
    private let requests = WeatherRequestCoordinator()
    private var contentLanguage: String?
    private var contentDate: Date?

    init(service: WeatherService = WeatherService(), now: @escaping () -> Date = Date.init) {
        self.service = service
        self.now = now
    }

    func refresh(lang: String) async {
        repeat {
            await requests.perform(language: lang) {
                let date = SolarDay.calendar.startOfDay(for: self.now())
                if self.contentLanguage != lang || self.contentDate != date {
                    self.section = WeatherDashboardSection()
                    self.contentLanguage = lang
                    self.contentDate = date
                }
                self.section.isLoading = true
                self.section.errorMessage = nil
                defer { self.section.isLoading = false }
                do {
                    let nextDate = SolarDay.calendar.date(byAdding: .day, value: 1, to: date)!
                    async let next: SolarDay? = try? self.service.solarTimes(on: nextDate)
                    let today = try await self.service.solarTimes(on: date)
                    let tomorrow = await next
                    try Task.checkCancellation()
                    guard date == SolarDay.calendar.startOfDay(for: self.now()) else { return }
                    self.section.value = SolarTimesSnapshot(today: today, tomorrow: tomorrow)
                    self.section.lastChecked = self.now()
                } catch is CancellationError {
                } catch let error as URLError where error.code == .cancelled {
                } catch {
                    self.section.errorMessage = WeatherServiceError.message(for: error, lang: lang)
                }
            }
            // A request that crosses midnight must load the new date, including
            // when the rollover refresh was coalesced with the previous request.
        } while !Task.isCancelled && contentDate != SolarDay.calendar.startOfDay(for: now())
    }
}
