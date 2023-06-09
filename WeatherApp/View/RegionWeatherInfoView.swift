//
//  RegionWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 30/4/2023.
//

import SwiftUI

struct RegionWeatherInfoView: View {
    @State var regionWeatherForecast = RegionWeatherForecast()
    @State var weatherType: String
    @ObservedObject var weatherViewModel: WeatherViewModel
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, content: {
                Text(LocalizedStringKey("region_weather_rainfall_title"))
                    .padding([.top], 10)
                    .font(.title)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(regionWeatherForecast.rainfall?.data ?? [], id: \.place) {(data) in
                            RegionalWeatherDetailView(regionRainfallData: data)
                        }
                    }
                }
                .padding([.leading, .trailing], 10)
            })
        }
        .padding([.leading, .trailing], 10)
        .onAppear(perform: {
            getRegionWeatherForecast()
        })
        .navigationTitle(LocalizedStringKey("region_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func getRegionWeatherForecast() {
        var urlComponents = URLComponents(string: weatherViewModel.baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: DataType().currentWeatherReport),
            URLQueryItem(name: "lang", value: Utils().getApiLanguageCode())
        ]
        
        guard let urlComponents = urlComponents else {
            return
        }
        
        weatherViewModel.getRegionWeatherForecast(urlComponents: urlComponents, completed: {(result) in
            self.regionWeatherForecast = result
        })
    }
}

struct RegionWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        RegionWeatherInfoView(weatherType: DataType().currentWeatherReport, weatherViewModel: WeatherViewModel())
    }
}
