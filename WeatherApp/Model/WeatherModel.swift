//
//  WeatherModel.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 9/8/2022.
//

import Foundation

// MARK: - DATA TYPE
struct DataType {
    var localWeatherForecast: String = "flw"
    var nineDayWeatherForecast: String = "fnd"
    var currentWeatherReport: String = "rhrread"
    var weatherWarningSummary: String = "warnsum"
    var weatherWarningInformation: String = "warningIndo"
    var specialWeatherTips: String = "swt"
}

// MARK: - DATA MODEL
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
}

struct RegionWeatherForecast: Codable {
    var rainfall: RainfallInfo?
    var updateTime: String?
}

struct CurrentWeatherReport: Codable {
    var lightning: LightningInfo?
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
    
}

struct RainfallInfo: Codable {
    var data: [RegionRainfallData]?
}

struct RegionRainfallData: Codable {
    var unit: String?
    var place: String?
    var min: Double?
    var max: Double?
    var main: String?
}
