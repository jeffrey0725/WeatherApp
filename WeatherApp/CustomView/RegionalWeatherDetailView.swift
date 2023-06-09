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
            Text("Max: \(regionRainfallData.max ?? 0)")
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
