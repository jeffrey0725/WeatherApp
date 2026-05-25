//
//  RegionalWeatherBottomSheetView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 6/4/2026.
//

import SwiftUI

struct RegionalWeatherBottomSheetView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var station: TemperatureData
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                print("Close pressed")
                dismiss()
            }, label: {
                Image(systemName: "xmark")
            })
        }
        .padding(.top, 20)
        .padding(.trailing, 20)
        
        VStack {
            if let _place = station.place {
                Text("\(String(localized: "region_weather_temperature_place")): \(_place)")
            }
            if let _value = station.value {
                Text("\(_value)")
            }
            
            #if DEBUG
            Text("Debug mode now")
            #endif
        }
        .padding(.top, 10)
        
        // All element align to top
        Spacer()
    }
}

#Preview {
    RegionalWeatherBottomSheetView(station: TemperatureData())
}
