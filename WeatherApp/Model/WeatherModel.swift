//
//  WeatherModel.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 9/8/2022.
//

import Foundation

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

// MARK: - REQUEST
struct RequestLocalWeatherForecast: Request {
    typealias ReturnType = LocalWeatherForecast
    var path: String = ""
}
