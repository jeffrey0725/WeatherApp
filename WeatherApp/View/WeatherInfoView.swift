//
//  WeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 14/9/2022.
//

import SwiftUI

struct WeatherInfoView: View {
    @State var localWeatherForecast = LocalWeatherForecast()
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    var body: some View {
        ScrollView {
            Text(localWeatherForecast.forecastDesc ?? "")
                .onAppear(perform: {
                    getWeather()
                })
                .padding(.leading, 20)
                .padding(.trailing, 20)
            Spacer()
        }
        .navigationTitle("Local Weather Information")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getWeather() {
        weatherViewModel.getLocalWeatherForcast(dataType: DataType().localWeatherForecast, lang: "en", completed: { (result) in
            self.localWeatherForecast = result
        })
    }
}

struct WeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherInfoView(weatherViewModel: WeatherViewModel())
    }
}
