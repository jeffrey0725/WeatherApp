import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "zh": return .traditionalChinese
            case "en": return .english
            default: continue
            }
        }
        return .english
    }

    var locale: Locale {
        Locale(identifier: resolved() == .traditionalChinese ? "zh_Hant_HK" : "en_HK")
    }

    var apiCode: String { resolved() == .traditionalChinese ? "tc" : "en" }

    static func forAPI(_ code: String) -> AppLanguage {
        code == "en" ? .english : .traditionalChinese
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit
    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }
}

protocol SettingsStorage {
    func read(_ key: String) -> String?
    func write(_ value: String, forKey key: String)
}

struct UserDefaultsSettingsStorage: SettingsStorage {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func read(_ key: String) -> String? { defaults.string(forKey: key) }
    func write(_ value: String, forKey key: String) { defaults.set(value, forKey: key) }
}

enum AppLocalization {
    static func text(_ key: String, locale: Locale = .current, bundle: Bundle = .main) -> String {
        let language = locale.language.languageCode?.identifier == "zh" ? "zh-Hant" : "en"
        // Choose the strings bundle explicitly; SwiftUI's locale environment does
        // not change the process language used by Foundation's string lookups.
        if let url = bundle.url(forResource: language, withExtension: "lproj"), let localized = Bundle(url: url) {
            return localized.localizedString(forKey: key, value: nil, table: nil)
        }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let languageKey = "weather.settings.language"
    static let temperatureUnitKey = "weather.settings.temperatureUnit"

    @Published var language: AppLanguage {
        didSet { storage.write(language.rawValue, forKey: Self.languageKey) }
    }
    @Published var temperatureUnit: TemperatureUnit {
        didSet { storage.write(temperatureUnit.rawValue, forKey: Self.temperatureUnitKey) }
    }

    private let storage: any SettingsStorage
    private let localizationBundle: Bundle

    init(storage: any SettingsStorage = UserDefaultsSettingsStorage(), localizationBundle: Bundle = .main) {
        self.storage = storage
        self.localizationBundle = localizationBundle
        language = storage.read(Self.languageKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
        temperatureUnit = storage.read(Self.temperatureUnitKey).flatMap(TemperatureUnit.init(rawValue:)) ?? .celsius
    }

    var locale: Locale { language.locale }
    var apiLanguageCode: String { language.apiCode }

    func text(_ key: String) -> String { AppLocalization.text(key, locale: locale, bundle: localizationBundle) }
    func timestamp(_ text: String?) -> String? { WeatherFormatting.timestamp(text, locale: locale) }
    func timestamp(_ date: Date) -> String { WeatherFormatting.timestamp(date, locale: locale) }
    func forecastDate(_ text: String?) -> String {
        WeatherFormatting.forecastDate(text, locale: locale, bundle: localizationBundle)
    }
    func measurement(_ value: Int?, unit: String?) -> String {
        WeatherFormatting.measurement(value, unit: unit, temperatureUnit: temperatureUnit, locale: locale,
                                      bundle: localizationBundle)
    }
    func range(min: Int?, max: Int?, unit: String?) -> String {
        WeatherFormatting.range(min: min, max: max, unit: unit, temperatureUnit: temperatureUnit, locale: locale,
                                bundle: localizationBundle)
    }

    static var preview: AppSettings { AppSettings(storage: PreviewSettingsStorage()) }
}

private final class PreviewSettingsStorage: SettingsStorage {
    private var values: [String: String] = [:]
    func read(_ key: String) -> String? { values[key] }
    func write(_ value: String, forKey key: String) { values[key] = value }
}
