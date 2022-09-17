//
//  WeatherViewModel.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 14/9/2022.
//

import Foundation

class WeatherViewModel: ObservableObject {
    @Published var baseUrl: String = "https://data.weather.gov.hk/weatherAPI/opendata/weather.php"
    @Published var localWeatherForcast = LocalWeatherForecast()
    
    func getLocalWeatherForcast(dataType: String, lang: String, completed: @escaping (LocalWeatherForecast) -> ()) {
        var urlComponents = URLComponents(string: baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: dataType),
            URLQueryItem(name: "lang", value: lang)
        ]
        
        URLSession.shared.dataTask(with: (urlComponents?.url)!, completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code:\n\(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                return
            }
            
            let result = try! JSONDecoder().decode(LocalWeatherForecast.self, from: data)
            print("JSON result:\n\(result)")
            DispatchQueue.main.async {
                completed(result)
            }
        }).resume()
    }
}
