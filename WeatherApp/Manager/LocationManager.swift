//
//  LocationManager.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 30/8/2025.
//

import Foundation
import CoreLocation


final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    var manager = CLLocationManager()
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
}

extension LocationManager {
    func checkLocationAuthorization() {
        manager.delegate = self
        manager.startUpdatingLocation()
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            break
        case .restricted:
            break
        case .denied:
            break
        case .authorizedAlways:
            print("debug: location enabled always")
            break
        case .authorizedWhenInUse:
            print("debug: location enabled when in use")
            manager.requestAlwaysAuthorization()
            break
        @unknown default:
            print("debug: location disabled")
            break
        }
    }
}
