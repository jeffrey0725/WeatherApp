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
                Text(LocalizedStringKey("nine_weather_title"))
                    .font(.title)
                ForEach(nineDayWeatherForecast.weatherForecast ?? [], id: \.forecastDate) { (data) in
                    DailyWeatherDetailView(weatherForecast: data)
                }
                Spacer()
                Text(LocalizedStringKey("general_situtation"))
                    .font(.title)
                Text("\(nineDayWeatherForecast.generalSituation ?? "")")
                    .font(.subheadline)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 10)
        .onAppear(perform: {
            getNineDayWeatherForecast()
        })
        .navigationTitle(LocalizedStringKey("nine_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getNineDayWeatherForecast() {
        var systemCode: String = ""
        if #available(iOS 16, *) {
            systemCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            systemCode = Locale.current.languageCode ?? "en"
        }
        
        var urlComponents = URLComponents(string: weatherViewModel.baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: DataType().nineDayWeatherForecast),
            URLQueryItem(name: "lang", value: getCode(systemCode))
        ]
        
        guard let urlComponents = urlComponents else {
            return
        }
        
        weatherViewModel.getNineDayWeatherForecast(urlComponents: urlComponents, completed: { (result) in
            self.nineDayWeatherForecast = result
        })
    }
    
    private func getCode(_ systemLangCode: String) -> String {
        switch systemLangCode {
        case "en":
            return "en"
        case "zh":
            return "tc"
        default:
            return "tc"
        }
    }
}

struct NineDayWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NineDayWeatherInfoView(weatherType: DataType().nineDayWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
