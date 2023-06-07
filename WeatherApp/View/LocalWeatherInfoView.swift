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
            Text(localWeatherForecast.forecastDesc ?? "")
                .onAppear(perform: {
                    getLocalWeather()
                })
                .padding([.leading, .trailing], 20)
            Spacer()
        }
        .navigationTitle(LocalizedStringKey("local_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func getLocalWeather() {
        // For language code, will apply system language code, default "tc"
        // For weather type which is passed from previous page
        weatherViewModel.getLocalWeatherForecast(dataType: weatherType, lang: Utils().getApiLanguageCode(), completed: {(result) in
            self.localWeatherForecast = result
        })
    }
}

struct LocalWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
