//
//  RegionMapView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 29/8/2025.
//

import SwiftUI
import MapKit
import Combine

struct RegionMapView: View {
    private var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.500702, longitude: -0.124562), latitudinalMeters: 1000, longitudinalMeters: 1000)
    
    var body: some View {
        if #available(iOS 17.0, *) {
            
            // Map View
            Map(initialPosition: .region(region)) {
                Marker(coordinate: CLLocationCoordinate2D(latitude: 51.500702, longitude: -0.124562), label: {
                    Text("Big Ben")
                })
            }
            .frame(height: 500)
        } else {
            // Fallback on earlier versions
        }
    }
}

#Preview {
    RegionMapView()
}
