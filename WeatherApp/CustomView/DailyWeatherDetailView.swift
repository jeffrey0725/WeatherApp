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
            Text("\(weatherForecast.forecastDate ?? "") (\(weatherForecast.week ?? ""))")
                .font(.title2)
            
            HStack {
                Text(weatherForecast.forecastWeather ?? "")
                    .font(.subheadline)
                Spacer()
                AsyncImage(url: URL(string: "https://www.hko.gov.hk/images/HKOWxIconOutline/pic\(weatherForecast.ForecastIcon ?? 0).png"), content: { (image) in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .background(Color.blue)
                        .cornerRadius(5)
                }, placeholder: {
                    ProgressView()
                })
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
}

struct DailyWeatherDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DailyWeatherDetailView(weatherForecast: WeatherForecast())
    }
}
