//
//  RegionalWeatherDetailView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 7/6/2023.
//

import SwiftUI

struct RegionalWeatherDetailView: View {
    @State var regionRainfallData: RegionRainfallData
    var body: some View {
        VStack {
            Text("\(regionRainfallData.place ?? "")")
            Text("\(String(localized: "region_weather_rainfall_max")): \(regionRainfallData.max ?? 0)\(regionRainfallData.unit ?? "")")
                .padding([.leading, .trailing], 5)
            Text("\(String(localized: "region_weather_rainfall_min")): \(regionRainfallData.min ?? 0)\(regionRainfallData.unit ?? "")")
                .padding([.leading, .trailing], 5)
        }
        .background(Color.yellow)
        .cornerRadius(5)
    }
}

struct RegionalWeatherDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RegionalWeatherDetailView(regionRainfallData: RegionRainfallData())
    }
}
