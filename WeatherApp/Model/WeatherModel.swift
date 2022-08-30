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
    var nineDaysWeatherForecast: String = "fnd"
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
