//
//  HomeView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 14/9/2022.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel()), label: {
                    Text(String(localized: "local_weather_title"))
                })
                
                NavigationLink(destination: NineDayWeatherInfoView(weatherType: DataType().nineDayWeatherForecast, weatherViewModel: WeatherViewModel()), label: {
                    Text(String(localized: "nine_weather_title"))
                })
                
                NavigationLink(destination: RegionWeatherInfoView(weatherType: DataType().currentWeatherReport, weatherViewModel: WeatherViewModel()), label: {
                    Text(String(localized: "region_weather_title"))
                })
            }
            .listStyle(.plain)
            .navigationTitle(String(localized: "home_view_title"))
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
