//
//  WeatherModel.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 9/8/2022.
//

import Foundation

// MARK: - BannerItem type
struct BannerItem: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - Data type
enum WeatherDataType: String, CaseIterable {
    case localWeatherForecast = "flw"
    case nineDayWeatherForecast = "fnd"
    case currentWeatherReport = "rhrread"
    case weatherWarningSummary = "warnsum"
    case weatherWarningInformation = "warningInfo"
    case specialWeatherTips = "swt"
}

// MARK: - Data model
struct LocalWeatherForecast: Codable {
    var generalSituation: String?
    var tcInfo: String?
    var fireDangerWarning: String?
    var forecastPeriod: String?
    var forecastDesc: String?
    var outlook: String?
    var updateTime: String?
}

struct NineDayWeatherForecast: Codable {
    var generalSituation: String?
    var weatherForecast: [WeatherForecast]?
    var updateTime: String?

    var preview: [WeatherForecast] { Array((weatherForecast ?? []).prefix(3)) }
}

struct RegionWeatherForecast: Codable {
    var rainfall: RainfallInfo?
    var updateTime: String?
    var lightning: LightningInfo?
    var temperature: TemperatureInfo?
    var humidity: HumidityInfo?
    var icon: [Int]?
    var iconUpdateTime: String?
    var uvindex: UVIndexInfo?
    var specialWxTips: [String]?
    var warningMessage: [String]?
    var tcmessage: [String]?
    var speicalWxTips: [String]?
}

// The API returns the message fields as either a string or an array of strings.
// Declared in an extension so the synthesized `RegionWeatherForecast()` init is kept.
extension RegionWeatherForecast {
    // Never substitute another district when the Observatory reading is missing.
    var observatoryTemperature: TemperatureData? {
        temperature?.data?.first { Self.isObservatory($0.place) }
    }

    var observatoryHumidity: HumidityData? {
        humidity?.data?.first { Self.isObservatory($0.place) }
    }

    private static func isObservatory(_ place: String?) -> Bool {
        place == "Hong Kong Observatory" || place == "香港天文台"
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rainfall = try c.decodeIfPresent(RainfallInfo.self, forKey: .rainfall)
        updateTime = try c.decodeIfPresent(String.self, forKey: .updateTime)
        lightning = try c.decodeIfPresent(LightningInfo.self, forKey: .lightning)
        temperature = try c.decodeIfPresent(TemperatureInfo.self, forKey: .temperature)
        humidity = try c.decodeIfPresent(HumidityInfo.self, forKey: .humidity)
        icon = try c.decodeIfPresent([Int].self, forKey: .icon)
        iconUpdateTime = try c.decodeIfPresent(String.self, forKey: .iconUpdateTime)
        // HKO returns an empty string when there is no UV observation.
        if let text = try? c.decode(String.self, forKey: .uvindex), text.isEmpty {
            uvindex = nil
        } else {
            uvindex = try c.decodeIfPresent(UVIndexInfo.self, forKey: .uvindex)
        }
        specialWxTips = try Self.decodeStrings(c, .specialWxTips)
        warningMessage = try Self.decodeStrings(c, .warningMessage)
        tcmessage = try Self.decodeStrings(c, .tcmessage)
        speicalWxTips = try Self.decodeStrings(c, .speicalWxTips)
    }

    private static func decodeStrings(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> [String]? {
        guard c.contains(key), try !c.decodeNil(forKey: key) else { return nil }
        if let string = try? c.decode(String.self, forKey: key) {
            return string.isEmpty ? nil : [string]
        }
        return try c.decode([String].self, forKey: key).filter { !$0.isEmpty }
    }
}

struct WeatherForecast: Codable {
    var forecastDate: String?
    var week: String?
    var forecastWind: String?
    var forecastWeather: String?
    var forecastMaxtemp: ForecastValueWithUnit?
    var forecastMintemp: ForecastValueWithUnit?
    var forecastMaxrh: ForecastValueWithUnit?
    var forecastMinrh: ForecastValueWithUnit?
    var ForecastIcon: Int?
    var PSR: String?
}

struct ForecastValueWithUnit: Codable {
    var value: Int?
    var unit: String?
}

struct OtherTemp: Codable {
    var place: String?
    var value: Float?
    var unit: String?
    var recordTime: String?
    var depth: ForecastValueWithUnit?
}

struct LightningInfo: Codable {
    var data: [RegionLightningData]?
}

struct RegionLightningData: Codable {
    var place: String?
    var occur: String?
}

struct RainfallInfo: Codable {
    var data: [RegionRainfallData]?
    var startTime: String?
    var endTime: String?
}

struct RegionRainfallData: Codable {
    var unit: String?
    var place: String?
    var min: Int?
    var max: Int?
    var main: String?
}

struct TemperatureInfo: Codable {
    var data: [TemperatureData]?
    var recordTime: String?
}

struct TemperatureData: Codable, Identifiable {
    var id = UUID()
    var place: String?
    var unit: String?
    var value: Int?
    var latitude: Double?
    var longitude: Double?
    
    enum CodingKeys: String, CodingKey {
        case place
        case unit
        case value
        case latitude
        case longitude
    }
}

struct HumidityInfo: Codable {
    var data: [HumidityData]?
    var recordTime: String?
}

struct HumidityData: Codable {
    var place: String?
    var value: Int?
    var unit: String?
}

struct UVIndexInfo: Codable {
    var data: [UVIndexData]?
    var recordDesc: String?
    var message: String?
}

struct UVIndexData: Codable {
    var place: String?
    var value: Double?
    var desc: String?
}

// warnsum is an object keyed by warning statement code, not a JSON array.
typealias WeatherWarningSummary = [String: WeatherWarning]

struct WeatherWarning: Codable {
    var name: String?
    var code: String?
    var type: String?
    var actionCode: String?
    var issueTime: String?
    var expireTime: String?
    var updateTime: String?

    func isActive(at date: Date = Date()) -> Bool {
        guard let code, !code.isEmpty, code.uppercased() != "CANCEL",
              actionCode?.uppercased() != "CANCEL" else { return false }
        if let expireTime, let expiry = ISO8601DateFormatter().date(from: expireTime) {
            return expiry > date
        }
        return true
    }
}

struct WeatherWarningInformation: Codable {
    var details: [WeatherWarningDetail]?
}

struct WeatherWarningDetail: Codable {
    var contents: [String]?
    var warningStatementCode: String?
    var subtype: String?
    var updateTime: String?
}

struct SpecialWeatherTips: Codable {
    var swt: [SpecialWeatherTip]?
}

struct SpecialWeatherTip: Codable {
    var desc: String?
    var updateTime: String?
}

struct WeatherWarningReport {
    /// Report parts that did not load. The summary decides which warnings are active, so it is required and
    /// cannot be missing; the statements and the special tips only add detail.
    enum Part: Hashable { case information, tips }

    var summary: WeatherWarningSummary = [:]
    var information = WeatherWarningInformation()
    var tips = SpecialWeatherTips()
    var missingParts: Set<Part> = []

    func activeWarningKeys(at date: Date = Date()) -> [String] {
        summary.keys.filter { summary[$0]?.isActive(at: date) == true }.sorted()
    }

    /// A warning's statement, or why there is none: a statement that failed to load is not the same as a
    /// warning that has no statement.
    func detailsText(for key: String, warning: WeatherWarning, noDetailsText: String, unavailableText: String) -> String {
        missingParts.contains(.information) ? unavailableText
            : details(for: key, warning: warning, noDetailsText: noDetailsText)
    }

    func details(for key: String, warning: WeatherWarning,
                 noDetailsText: String = AppLocalization.text("weather_warning_no_details")) -> String {
        let contents = (information.details ?? [])
            .filter { $0.warningStatementCode == key && ($0.subtype == nil || $0.subtype == warning.code) }
            .flatMap { $0.contents ?? [] }
            .filter { !$0.isEmpty }
        return contents.isEmpty ? noDetailsText : contents.joined(separator: "\n\n")
    }
}

// MARK: - Display data model
struct RegionalWeatherDetail: Codable {
    var topTitle: String?
    var middleTitle: String?
    var bottomTitle: String?
}
