//
//  LocalWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 18/9/2022.
//

import SwiftUI

struct LocalWeatherInfoView: View {
    @State var localWeatherForecast = LocalWeatherForecast()
    @State var weatherType: String
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    var body: some View {
        ScrollView {
            Text(localWeatherForecast.generalSituation ?? "")
//                .padding([.leading, .trailing], 20)
                .padding([.bottom], 10)
            Text(localWeatherForecast.forecastDesc ?? "")
//                .padding([.leading, .trailing], 20)
                .padding([.bottom], 10)
            Spacer()
            Text(localWeatherForecast.tcInfo ?? "123123")
//                .padding([.leading, .trailing], 20)
        }
        .navigationTitle(String(localized: "local_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            NSLog("LocalWeatherInfoView enter")
            getLocalWeather()
        }
    }
    
    func getLocalWeather() {
        // For language code, will apply system language code, default "tc"
        // For weather type which is passed from previous page
        // Use background thread to call api
        DispatchQueue.global(qos: .userInitiated).async {
            weatherViewModel.getLocalWeatherForecast(dataType: weatherType, lang: Utils().getApiLanguageCode(), completed: { (result) in
                self.localWeatherForecast = result
            })
        }
    }
}

struct LocalWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
