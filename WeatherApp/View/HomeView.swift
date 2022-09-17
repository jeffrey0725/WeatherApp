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
                NavigationLink(destination: WeatherInfoView(weatherViewModel: WeatherViewModel()), label: {
                    Text("Weather Information")
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
