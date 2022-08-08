//
//  APIManager.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/8/2022.
//

import Foundation
import Combine

class APIManager {
    private static let instance: APIManager = APIManager()
    public static func getInstance() -> APIManager {
        return instance
    }
    
    
}
