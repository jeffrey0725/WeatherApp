//
//  ContentView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/8/2022.
//

import SwiftUI

struct ContentView: View {
    @State var localWeatherForecast = LocalWeatherForecast()
    var body: some View {
        NavigationView {
            VStack {
                Text(localWeatherForecast.forecastDesc ?? "")
                    .padding()
            }
            .toolbar(content: {
                NavigationLink(destination: SettingView(), label: {
                    Image(systemName: "gearshape")
                })
                    .buttonStyle(.plain)
            })
            .onAppear(perform: {
                APIManager().getLocalWeatherForcast(dataType: DataType().localWeatherForecast, lang: "en", completed: { (result) in
                    self.localWeatherForecast = result
                })
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
