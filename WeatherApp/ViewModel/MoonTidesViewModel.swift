import Foundation
import Combine

@MainActor
final class MoonTidesViewModel: ObservableObject {
    @Published private(set) var moon = WeatherDashboardSection<MoonTimesSnapshot>()
    @Published private(set) var tides = WeatherDashboardSection<TideTimesSnapshot>()
    private let service: WeatherService
    private let now: () -> Date
    private let requests = WeatherRequestCoordinator()
    private var contentLanguage: String?
    private var contentStation: String?
    private var contentDate: Date?

    var isLoading: Bool { moon.isLoading || tides.isLoading }

    init(service: WeatherService = WeatherService(), now: @escaping () -> Date = Date.init) {
        self.service = service
        self.now = now
    }

    func refresh(lang: String, station: TideStation) async {
        repeat {
            // A language or station change supersedes the request in flight, like a language change elsewhere.
            await requests.perform(language: "\(lang)|\(station.id)") {
                let date = SolarDay.calendar.startOfDay(for: self.now())
                if self.contentLanguage != lang || self.contentDate != date {
                    self.moon = WeatherDashboardSection()
                    self.tides = WeatherDashboardSection()
                } else if self.contentStation != station.id {
                    // Never show one station's tides under another station's name.
                    self.tides = WeatherDashboardSection()
                }
                self.contentLanguage = lang
                self.contentStation = station.id
                self.contentDate = date
                async let moon: Void = self.loadMoon(lang: lang, date: date)
                async let tides: Void = self.loadTides(lang: lang, station: station, date: date)
                _ = await (moon, tides)
            }
            // A request that crosses midnight must load the new date, including
            // when the rollover refresh was coalesced with the previous request.
        } while !Task.isCancelled && contentDate != SolarDay.calendar.startOfDay(for: now())
    }

    // Today must load; tomorrow is optional so its failure does not hide today's times.
    private func loadMoon(lang: String, date: Date) async {
        let nextDate = SolarDay.calendar.date(byAdding: .day, value: 1, to: date)!
        await load(\.moon, lang: lang, date: date) {
            async let next: MoonDay? = try? self.service.moonTimes(on: nextDate)
            let today = try await self.service.moonTimes(on: date)
            return MoonTimesSnapshot(today: today, tomorrow: await next)
        }
    }

    private func loadTides(lang: String, station: TideStation, date: Date) async {
        let nextDate = SolarDay.calendar.date(byAdding: .day, value: 1, to: date)!
        await load(\.tides, lang: lang, date: date) {
            async let next: TideDay? = try? self.service.tideTimes(at: station, on: nextDate)
            let today = try await self.service.tideTimes(at: station, on: date)
            return TideTimesSnapshot(station: station, today: today, tomorrow: await next)
        }
    }

    private func load<Value>(
        _ keyPath: ReferenceWritableKeyPath<MoonTidesViewModel, WeatherDashboardSection<Value>>,
        lang: String,
        date: Date,
        operation: () async throws -> Value
    ) async {
        self[keyPath: keyPath].isLoading = true
        self[keyPath: keyPath].errorMessage = nil
        defer { self[keyPath: keyPath].isLoading = false }
        do {
            let value = try await operation()
            try Task.checkCancellation()
            guard date == SolarDay.calendar.startOfDay(for: now()) else { return }
            self[keyPath: keyPath].value = value
            self[keyPath: keyPath].lastChecked = now()
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            self[keyPath: keyPath].errorMessage = WeatherServiceError.message(for: error, lang: lang)
        }
    }
}
