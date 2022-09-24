//
//  NineDayWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 18/9/2022.
//

import SwiftUI

struct NineDayWeatherInfoView: View {
    @State var nineDayWeatherForecast = NineDayWeatherForecast()
    @State var weatherType: String
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
    
    private func getNineDayWeatherForecast() {
        var langCode: String = ""
        if #available(iOS 16, *) {
            langCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            langCode = Locale.current.languageCode ?? "en"
        }
    }
}

struct NineDayWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NineDayWeatherInfoView(weatherType: DataType().nineDayWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
