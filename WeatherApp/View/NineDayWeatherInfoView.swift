//
//  NineDayWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 18/9/2022.
//

import SwiftUI

struct NineDayWeatherInfoView: View {
    @State var nineDayWeatherForecast = NineDayWeatherForecast()
    @State var weatherType: String
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Nine days weather info")
                
                ForEach(nineDayWeatherForecast.weatherForecast ?? [], id: \.forecastDate) { (data) in
                    DailyWeatherDetailView(weatherForecast: data)
                }
                
                Spacer()
                
                Text("General Situation")
                	
            }
        }
        .onAppear(perform: {
            getNineDayWeatherForecast()
        })
        .navigationTitle("Nine days weather info")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getNineDayWeatherForecast() {
        var langCode: String = ""
        if #available(iOS 16, *) {
            langCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            langCode = Locale.current.languageCode ?? "en"
        }
        
        var urlComponents = URLComponents(string: weatherViewModel.baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: DataType().nineDayWeatherForecast),
            URLQueryItem(name: "lang", value: langCode)
        ]
        
        guard let urlComponents = urlComponents else {
            return
        }
        
        weatherViewModel.getNineDayWeatherForecast(urlComponents: urlComponents, completed: { (result) in
            self.nineDayWeatherForecast = result
        })
    }
}

struct NineDayWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NineDayWeatherInfoView(weatherType: DataType().nineDayWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
