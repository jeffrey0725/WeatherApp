//
//  RegionalWeatherDetailView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 7/6/2023.
//

import SwiftUI

struct RegionalWeatherDetailView: View {
    @State var regionalWeatherDetail: RegionalWeatherDetail
    
    var body: some View {
        VStack {
            if let topTitle = regionalWeatherDetail.topTitle {
                Text(topTitle)
                    .padding([.leading, .trailing], 5)
            }
            if let middleTitle = regionalWeatherDetail.middleTitle {
                Text(middleTitle)
                    .padding([.leading, .trailing], 5)
            }
            if let bottomTitle = regionalWeatherDetail.bottomTitle {
                Text(bottomTitle)
                    .padding([.leading, .trailing], 5)
            }
        }
        .frame(width: 100, height: 80)
        .background(Color.yellow)
        .cornerRadius(5)
    }
}

struct RegionalWeatherDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RegionalWeatherDetailView(regionalWeatherDetail: RegionalWeatherDetail())
    }
}
