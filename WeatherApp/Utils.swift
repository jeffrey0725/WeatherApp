//
//  Utils.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 2/6/2023.
//

import Foundation

class Utils: NSObject {
    func getApiLanguageCode() -> String {
        switch getSystemLanguageCode() {
        case "en":
            return "en"
        case "zh":
            return "tc"
        default:
            return "tc"
        }
    }
    
    func getSystemLanguageCode() -> String {
        if #available(iOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            // Fallback on earlier versions
            return Locale.current.languageCode ?? "en"
        }
    }
}
