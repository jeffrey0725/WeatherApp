//
//  DailyWeatherDetailView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 29/9/2022.
//

import SwiftUI

struct DailyWeatherDetailView: View {
    @State var weatherForecast: WeatherForecast
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(weatherForecast.forecastDate ?? "")
                .font(.title)
            
            HStack {
                Text(weatherForecast.forecastWeather ?? "")
                    .font(.subheadline)
            }
        }
        .padding()
    }
}

struct DailyWeatherDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DailyWeatherDetailView(weatherForecast: WeatherForecast())
    }
}
