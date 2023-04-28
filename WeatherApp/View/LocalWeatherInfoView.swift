//
//  LocalWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 18/9/2022.
//

import SwiftUI

struct LocalWeatherInfoView: View {
    @State var localWeatherForecast = LocalWeatherForecast()
    @State var weatherType: String
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    var body: some View {
        ScrollView {
            Text(localWeatherForecast.forecastDesc ?? "")
                .onAppear(perform: {
                    getLocalWeather()
                })
                .padding(.leading, 20)
                .padding(.trailing, 20)
            Spacer()
        }
        .navigationTitle("Local Weather Information")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getLocalWeather() {
        // Check system language code
        var systemCode: String = ""
        if #available(iOS 16, *) {
            systemCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            systemCode = Locale.current.languageCode ?? "en"
        }
        
        // For language code, will apply system language code, default "en"
        // For weather type which is passed from previous page
        weatherViewModel.getLocalWeatherForecast(dataType: weatherType, lang: getLangCode(systemCode), completed: { (result) in
            self.localWeatherForecast = result
        })
    }
    
    private func getLangCode(_ systemCode: String) -> String {
        switch systemCode {
        case "en":
            return "en"
        case "zh":
            return "tc"
        default:
            return "tc"
        }
    }
}

struct LocalWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
