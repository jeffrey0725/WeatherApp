//
//  Utils.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 2/6/2023.
//

import Foundation

class Utils: NSObject {
    func getApiLanguageCode() -> String {
        // Will get system language code
        switch getSystemLanguageCode() {
        case "en":
            return "en"
        case "zh":
            return "tc"
        default:
            return "tc"
        }
    }
    
    func getSystemLanguageCode() -> String {
        if #available(iOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            return Locale.current.languageCode ?? "en"
        }
    }
    
    func getCurrentDate(dateFormat: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        dateFormatter.timeZone = .current
        return dateFormatter.string(from: Date.now)
    }
}

// MARK: - Extension for String

enum Language: String {
    case english_us = "en"
    case traditional_chinese = "zh"
}

enum WeatherFormatting {
    static func timestamp(_ text: String?, locale: Locale = .current) -> String? {
        guard let text, let date = ISO8601DateFormatter().date(from: text) else { return nil }
        return timestamp(date, locale: locale)
    }

    static func timestamp(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func forecastDate(_ text: String?, locale: Locale = .current, bundle: Bundle = .main) -> String {
        guard let text else { return AppLocalization.text("weather_unavailable", locale: locale, bundle: bundle) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyyMMdd"
        guard let date = formatter.date(from: text) else { return text }
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func measurement(_ value: Int?, unit: String?, temperatureUnit: TemperatureUnit = .celsius,
                            locale: Locale = .current, bundle: Bundle = .main) -> String {
        guard let value else { return AppLocalization.text("weather_unavailable", locale: locale, bundle: bundle) }
        return "\(displayValue(value, unit: unit, temperatureUnit: temperatureUnit, locale: locale))\(displayUnit(unit, temperatureUnit: temperatureUnit))"
    }

    static func range(min: Int?, max: Int?, unit: String?, temperatureUnit: TemperatureUnit = .celsius,
                      locale: Locale = .current, bundle: Bundle = .main) -> String {
        let unavailable = AppLocalization.text("weather_unavailable", locale: locale, bundle: bundle)
        let low = min.map { displayValue($0, unit: unit, temperatureUnit: temperatureUnit, locale: locale) } ?? unavailable
        let high = max.map { displayValue($0, unit: unit, temperatureUnit: temperatureUnit, locale: locale) } ?? unavailable
        return "\(low)–\(high)\(displayUnit(unit, temperatureUnit: temperatureUnit))"
    }

    private static func displayValue(_ value: Int, unit: String?, temperatureUnit: TemperatureUnit, locale: Locale) -> String {
        guard unit == "C", temperatureUnit == .fahrenheit else { return String(value) }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: Double(value) * 9 / 5 + 32)) ?? String(value)
    }

    private static func displayUnit(_ unit: String?, temperatureUnit: TemperatureUnit) -> String {
        switch unit {
        case "C": return " \(temperatureUnit.symbol)"
        case "percent", "%": return "%"
        case .some(let unit) where !unit.isEmpty: return " \(unit)"
        default: return ""
        }
    }
}
