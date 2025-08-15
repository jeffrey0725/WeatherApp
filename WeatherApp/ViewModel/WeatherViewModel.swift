//
//  WeatherViewModel.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 14/9/2022.
//

import Foundation
import Combine

class WeatherViewModel: ObservableObject {
    @Published var baseUrl: String = "https://data.weather.gov.hk/weatherAPI/opendata/weather.php"
    @Published var localWeatherForcast = LocalWeatherForecast()
    
    func getUrlWithQuery(dataType: String, lang: String) -> URLComponents {
        var urlComponents = URLComponents(string: baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: dataType),
            URLQueryItem(name: "lang", value: lang)
        ]
        return urlComponents!
    }
    
    func getLocalWeatherForecast(dataType: String, lang: String, completed: @escaping (LocalWeatherForecast) -> ()) {
        var urlComponents = URLComponents(string: baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: dataType),
            URLQueryItem(name: "lang", value: lang)
        ]
        
        URLSession.shared.dataTask(with: (urlComponents?.url)!, completionHandler: {(data, response, error) in
            guard let data = data else {
                return
            }
            
            let result = try! JSONDecoder().decode(LocalWeatherForecast.self, from: data)
            DispatchQueue.main.async {
                completed(result)
            }
        }).resume()
    }
    
    func getNineDayWeatherForecast(urlComponents: URLComponents, completed: @escaping (NineDayWeatherForecast) -> ()) {
        URLSession.shared.dataTask(with: (urlComponents.url)!, completionHandler: {(data, response, error) in
            guard let data = data else {
                return
            }
            
            let result = try! JSONDecoder().decode(NineDayWeatherForecast.self, from: data)
            
            DispatchQueue.main.async {
                completed(result)
            }
        }).resume()
    }
    
    func getRegionWeatherForecast(urlComponents: URLComponents, completed: @escaping (RegionWeatherForecast) -> ()) {
        guard let url = urlComponents.url else {
            return
        }
        
        URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return
            }
            
            guard let data = data else {
                return
            }
            
            let result = try! JSONDecoder().decode(RegionWeatherForecast.self, from: data)
            DispatchQueue.main.async {
                completed(result)
            }
        }).resume()
    }
}
