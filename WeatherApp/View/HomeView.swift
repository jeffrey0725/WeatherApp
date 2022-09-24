//
//  HomeView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 14/9/2022.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel()), label: {
                    Text("Local Weather Forecast")
                })
                
                NavigationLink(destination: NineDayWeatherInfoView(weatherType: DataType().nineDayWeatherForecast, weatherViewModel: WeatherViewModel()), label: {
                    Text("9-day Weather Forecast")
                })
            }
            .listStyle(.plain)
            .navigationTitle("Home")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
