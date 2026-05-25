//
//  RegionMapView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 29/8/2025.
//

import SwiftUI
import MapKit
import Combine
import CoreLocation

struct RegionMapView: View { 
    @State private var selectedStation: TemperatureData?
    let stations: [TemperatureData]
    
    private let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            latitudinalMeters: 50000,
            longitudinalMeters: 50000
        )
    
    struct StationCoordinate: Identifiable {
        let id = UUID()
        let place: String
        let coordinate: CLLocationCoordinate2D
    }
    
    var body: some View {
        // Map View
        // No need to handle lower than iOS 17 case
        // As minimum support iOS version is iOS 17.6
        Map(initialPosition: .region(region)) {
            // Reserved for marker on map
            ForEach(stations) { (station) in
                if let _place = station.place, let _latitude = station.latitude, let _longitude = station.longitude, let _temperature = station.value, let _unit = station.unit {
                    Annotation(_place, coordinate: CLLocationCoordinate2D(latitude: _latitude, longitude: _longitude)) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(selectedStation?.id == station.id ? .red : .blue)
                            .onTapGesture {
                                selectedStation = station
                            }
                    }
                }
            }
        }
        .frame(height: 500)
        
        // Bottom sheet
        .sheet(item: $selectedStation) { (station) in
            RegionalWeatherBottomSheetView(station: station)
        }
    }
}

#Preview {
    RegionMapView(stations: [])
}
