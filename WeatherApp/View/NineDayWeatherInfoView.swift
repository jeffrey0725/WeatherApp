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
    
    func getNineDayWeatherForecast() {
        var urlComponents = URLComponents(string: weatherViewModel.baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: DataType().nineDayWeatherForecast),
            URLQueryItem(name: "lang", value: Utils().getApiLanguageCode())
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
