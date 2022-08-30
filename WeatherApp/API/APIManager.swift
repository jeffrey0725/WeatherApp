//
//  APIManager.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 29/8/2022.
//

import Foundation

class APIManager: ObservableObject {
    var baseUrl = "https://data.weather.gov.hk/weatherAPI/opendata/weather.php"
    @Published var localWeatherForcast = LocalWeatherForecast()
    
    func getLocalWeatherForcast(dataType: String, lang: String, completed: @escaping (LocalWeatherForecast) -> ()) {
        var components = URLComponents(string: baseUrl)
        components?.queryItems = [
            URLQueryItem(name: "dataType", value: dataType),
            URLQueryItem(name: "lang", value: lang)
        ]
        guard let url = components?.url else {
            return
        }
        URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                print("--------HTTP STATUS CODE--------\n\(httpResponse.statusCode)")
            }
            guard let data = data else {
                return
            }
            let result = try! JSONDecoder().decode(LocalWeatherForecast.self, from: data)
            print("--------DEBUG--------\n\(result)")
            DispatchQueue.main.async {
                completed(result)
            }
        }).resume()
    }
}
