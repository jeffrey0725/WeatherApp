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
            VStack(alignment: .leading) {
                Text(localWeatherForecast.generalSituation ?? "")
                    .padding([.leading, .trailing, .bottom], 10)
                Text(localWeatherForecast.forecastDesc ?? "")
                    .padding([.leading, .trailing, .bottom], 10)
                Text(localWeatherForecast.tcInfo ?? "")
                    .padding([.leading, .trailing, .bottom], 10)
            }
            Spacer()
        }
        .navigationTitle(String(localized: "local_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            Task {
                await getLocalWeather(.userInitiated)
            }
        }
        .refreshable {
            // If not using await, closure will complete immediately
            await getLocalWeather(.background)
        }
    }
}

private extension LocalWeatherInfoView {
    func getLocalWeather(_ runOnThread: DispatchQoS.QoSClass) async {
        await withCheckedContinuation { (continuation) in
            DispatchQueue.global(qos: runOnThread).async {
                weatherViewModel.getLocalWeatherForecast(
                    dataType: weatherType,
                    lang: Utils().getApiLanguageCode(),
                    completed: { (result) in
                        DispatchQueue.main.async {
                            self.localWeatherForecast = result
                            continuation.resume()
                        }
                    })
            }
        }
    }
}

struct LocalWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        LocalWeatherInfoView(weatherType: DataType().localWeatherForecast, weatherViewModel: WeatherViewModel())
    }
}
