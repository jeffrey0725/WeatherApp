import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class AppSettingsTests: XCTestCase {
    func testSystemLanguageChoosesSupportedPreferencesAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh-Hans-CN", "en-US"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hant-HK"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-Hant-HK"]), .english)
        XCTAssertEqual(AppLanguage.traditionalChinese.apiCode, "tc")
        XCTAssertEqual(AppLanguage.english.apiCode, "en")
    }

    func testPreferencesAreRestoredByANewSettingsInstance() {
        onMainActor {
            let storage = MemorySettingsStorage()
            let first = AppSettings(storage: storage)
            XCTAssertEqual(first.language, .system)
            XCTAssertEqual(first.temperatureUnit, .celsius)
            first.language = .traditionalChinese
            first.temperatureUnit = .fahrenheit
            let reopened = AppSettings(storage: storage)
            XCTAssertEqual(reopened.language, .traditionalChinese)
            XCTAssertEqual(reopened.temperatureUnit, .fahrenheit)
            XCTAssertEqual(reopened.apiLanguageCode, "tc")
            XCTAssertEqual(storage.values.count, 2)
        }
    }

    func testUnknownStoredValuesUseSafeDefaults() {
        onMainActor {
            let storage = MemorySettingsStorage()
            storage.values[AppSettings.languageKey] = "unsupported"
            storage.values[AppSettings.temperatureUnitKey] = "kelvin"
            let settings = AppSettings(storage: storage)
            XCTAssertEqual(settings.language, .system)
            XCTAssertEqual(settings.temperatureUnit, .celsius)
        }
    }

    func testAppLanguageOverridesBundleStringsAndFormattingWithoutChangingAPIUnits() {
        onMainActor {
            let settings = AppSettings(storage: MemorySettingsStorage(), localizationBundle: Bundle(for: Self.self))
            settings.language = .english
            XCTAssertEqual(settings.text("settings_title"), "Settings")
            XCTAssertEqual(settings.text("weather_today"), "Today")
            settings.language = .traditionalChinese
            XCTAssertEqual(settings.text("settings_title"), "設定")
            XCTAssertEqual(settings.text("weather_today"), "今日天氣")
            XCTAssertEqual(settings.measurement(nil, unit: "C"), "暫無資料")
            settings.temperatureUnit = .fahrenheit
            XCTAssertEqual(settings.measurement(27, unit: "C"), "81 °F")
            XCTAssertEqual(settings.apiLanguageCode, "tc")
            XCTAssertEqual(settings.range(min: nil, max: 27, unit: "C"), "暫無資料–81 °F")
        }
    }

    func testTemperatureConversionRoundsWholeDegreesAndHandlesZeroAndNegatives() {
        let locale = Locale(identifier: "en_HK")
        let examples = [(0, "32 °F"), (27, "81 °F"), (100, "212 °F"), (-40, "-40 °F"), (5, "41 °F")]
        for (value, expected) in examples {
            XCTAssertEqual(WeatherFormatting.measurement(value, unit: "C", temperatureUnit: .fahrenheit, locale: locale), expected)
        }
        XCTAssertEqual(WeatherFormatting.range(min: 25, max: 29, unit: "C", temperatureUnit: .fahrenheit, locale: locale), "77–84 °F")
        XCTAssertEqual(WeatherFormatting.measurement(27, unit: "C", locale: locale), "27 °C")
    }

    func testTemperaturePreferenceLeavesRainfallHumidityAndSourceValuesIntact() {
        onMainActor {
            let settings = AppSettings(storage: MemorySettingsStorage())
            settings.temperatureUnit = .fahrenheit
            let reading = TemperatureData(place: "Sha Tin", unit: "C", value: 27)
            XCTAssertEqual(settings.measurement(reading.value, unit: reading.unit), "81 °F")
            XCTAssertEqual(reading.value, 27)
            XCTAssertEqual(reading.unit, "C")
            XCTAssertEqual(settings.measurement(78, unit: "percent"), "78%")
            XCTAssertEqual(settings.measurement(0, unit: "mm"), "0 mm")
            XCTAssertEqual(settings.range(min: 70, max: 95, unit: "%"), "70–95%")
        }
    }

    func testSelectedLocaleFormatsDatesInHongKongTime() {
        let english = WeatherFormatting.timestamp("2026-10-13T16:00:00Z", locale: Locale(identifier: "en_HK"))
        let chinese = WeatherFormatting.timestamp("2026-10-13T16:00:00Z", locale: Locale(identifier: "zh_Hant_HK"))
        XCTAssertTrue(english?.contains("14") == true)
        XCTAssertTrue(chinese?.contains("14") == true)
        XCTAssertNotEqual(english, chinese)
        XCTAssertNil(WeatherFormatting.timestamp("bad timestamp", locale: Locale(identifier: "zh_Hant_HK")))
        XCTAssertNotEqual(WeatherFormatting.forecastDate("20261013", locale: Locale(identifier: "en_HK")),
                          WeatherFormatting.forecastDate("20261013", locale: Locale(identifier: "zh_Hant_HK")))
    }

    func testWeatherErrorsUseTheRequestedLanguage() {
        let bundle = Bundle(for: Self.self)
        XCTAssertEqual(WeatherServiceError.message(for: URLError(.notConnectedToInternet), lang: "tc", bundle: bundle),
                       "未能連線至天文台，請檢查網絡連線並重試。")
        XCTAssertEqual(WeatherServiceError.message(for: URLError(.timedOut), lang: "en", bundle: bundle),
                       "The weather request timed out. Please try again.")
    }

    func testOverlappingRefreshesWaitForOneRequest() {
        onMainActorAsync {
            let entered = self.expectation(description: "First request starts")
            let gate = SettingsRequestGate(onWait: { entered.fulfill() })
            defer { gate.release() }
            let coordinator = WeatherRequestCoordinator()
            var starts = 0
            let first = Task {
                await coordinator.perform(language: "en") { starts += 1; await gate.wait() }
            }
            await self.fulfillment(of: [entered], timeout: 2)
            let returnedEarly = self.expectation(description: "Second refresh waits")
            returnedEarly.isInverted = true
            let second = Task {
                await coordinator.perform(language: "en") { starts += 1 }
                if !gate.isReleased { returnedEarly.fulfill() }
            }
            await self.fulfillment(of: [returnedEarly], timeout: 0.1)
            gate.release()
            await first.value
            await second.value
            XCTAssertEqual(starts, 1)
        }
    }

    func testLanguageChangeCancelsTheOlderRequestAndRunsTheNewLanguage() {
        onMainActorAsync {
            let entered = self.expectation(description: "English request starts")
            let cancelled = self.expectation(description: "English request is superseded")
            let gate = SettingsRequestGate(onWait: { entered.fulfill() })
            defer { gate.release() }
            let coordinator = WeatherRequestCoordinator()
            var applied: [String] = []
            let first = Task {
                await coordinator.perform(language: "en") {
                    await withTaskCancellationHandler {
                        await gate.wait()
                    } onCancel: {
                        cancelled.fulfill()
                    }
                    if !Task.isCancelled { applied.append("en") }
                }
            }
            await self.fulfillment(of: [entered], timeout: 2)
            let second = Task { await coordinator.perform(language: "tc") { applied.append("tc") } }
            await self.fulfillment(of: [cancelled], timeout: 2)
            gate.release()
            await first.value
            await second.value
            XCTAssertEqual(applied, ["tc"])
        }
    }

    func testRapidLanguageChangesStartAFreshRequestAfterCancellation() {
        onMainActorAsync {
            let entered = self.expectation(description: "Original English request starts")
            let cancelled = self.expectation(description: "Original English request is cancelled")
            let gate = SettingsRequestGate(onWait: { entered.fulfill() })
            defer { gate.release() }
            let coordinator = WeatherRequestCoordinator()
            var applied: [String] = []
            let original = Task {
                await coordinator.perform(language: "en") {
                    await withTaskCancellationHandler {
                        await gate.wait()
                    } onCancel: { cancelled.fulfill() }
                    if !Task.isCancelled { applied.append("original en") }
                }
            }
            await self.fulfillment(of: [entered], timeout: 2)
            let chinese = Task { await coordinator.perform(language: "tc") { applied.append("tc") } }
            await self.fulfillment(of: [cancelled], timeout: 2)
            chinese.cancel()
            let latestStarted = self.expectation(description: "Latest English refresh is called")
            let latest = Task {
                latestStarted.fulfill()
                await coordinator.perform(language: "en") { applied.append("new en") }
            }
            await self.fulfillment(of: [latestStarted], timeout: 2)
            gate.release()
            await original.value
            await chinese.value
            await latest.value
            XCTAssertEqual(applied, ["new en"])
        }
    }

    private func onMainActor(_ operation: @escaping @MainActor () throws -> Void) {
        onMainActorAsync { try operation() }
    }

    private func onMainActorAsync(_ operation: @escaping @MainActor () async throws -> Void) {
        let completed = expectation(description: "Settings operation completes")
        Task { @MainActor in
            do { try await operation() }
            catch { XCTFail("Unexpected error: \(error)") }
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5)
    }
}

private final class MemorySettingsStorage: SettingsStorage {
    var values: [String: String] = [:]
    func read(_ key: String) -> String? { values[key] }
    func write(_ value: String, forKey key: String) { values[key] = value }
}

@MainActor
private final class SettingsRequestGate {
    private let onWait: () -> Void
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isReleased = false
    init(onWait: @escaping () -> Void) { self.onWait = onWait }
    func wait() async {
        guard !isReleased else { return }
        await withCheckedContinuation {
            continuation = $0
            onWait()
        }
    }
    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
