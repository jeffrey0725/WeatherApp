//
//  Static.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/3/2026.
//

import CoreLocation

struct StationCoordinate: Identifiable {
    let id = UUID()
    let placeTC: String
    let placeEN: String
    let coordinate: CLLocationCoordinate2D
}

struct StationCoordinateStore {
    static let stationCoordinates: [StationCoordinate] = [
        StationCoordinate(placeTC: "京士柏", placeEN: "King's Park", coordinate: .init(latitude: 22.3195, longitude: 114.1751)),
        StationCoordinate(placeTC: "香港天文台", placeEN: "Hong Kong Observatory", coordinate: .init(latitude: 22.3019, longitude: 114.1740)),
        StationCoordinate(placeTC: "黃竹坑", placeEN: "Wong Chuk Hang", coordinate: .init(latitude: 22.2470, longitude: 114.1700)),
        StationCoordinate(placeTC: "打鼓嶺", placeEN: "Ta Kwu Ling", coordinate: .init(latitude: 22.5280, longitude: 114.1470)),
        StationCoordinate(placeTC: "流浮山", placeEN: "Lau Fau Shan", coordinate: .init(latitude: 22.4690, longitude: 113.9970)),
        StationCoordinate(placeTC: "大埔", placeEN: "Tai Po", coordinate: .init(latitude: 22.4500, longitude: 114.1690)),
        StationCoordinate(placeTC: "沙田", placeEN: "Sha Tin", coordinate: .init(latitude: 22.3830, longitude: 114.1880)),
        StationCoordinate(placeTC: "屯門", placeEN: "Tuen Mun", coordinate: .init(latitude: 22.3910, longitude: 113.9710)),
        StationCoordinate(placeTC: "將軍澳", placeEN: "Tseung Kwan O", coordinate: .init(latitude: 22.3080, longitude: 114.2600)),
        StationCoordinate(placeTC: "西貢", placeEN: "Sai Kung", coordinate: .init(latitude: 22.3810, longitude: 114.2710)),
        StationCoordinate(placeTC: "長洲", placeEN: "Cheung Chau", coordinate: .init(latitude: 22.2080, longitude: 114.0260)),
        StationCoordinate(placeTC: "赤鱲角", placeEN: "Chek Lap Kok", coordinate: .init(latitude: 22.3080, longitude: 113.9185)),
        StationCoordinate(placeTC: "青衣", placeEN: "Tsing Yi", coordinate: .init(latitude: 22.3530, longitude: 114.1070)),
        StationCoordinate(placeTC: "石崗", placeEN: "Shek Kong", coordinate: .init(latitude: 22.4360, longitude: 114.0840)),
        StationCoordinate(placeTC: "荃灣可觀", placeEN: "Tsuen Wan Ho Koon", coordinate: .init(latitude: 22.3836, longitude: 114.1040)),
        StationCoordinate(placeTC: "荃灣城門谷", placeEN: "Tsuen Wan Shing Mun Valley", coordinate: .init(latitude: 22.3750, longitude: 114.1230)),
        StationCoordinate(placeTC: "香港公園", placeEN: "Hong Kong Park", coordinate: .init(latitude: 22.2776, longitude: 114.1617)),
        StationCoordinate(placeTC: "筲箕灣", placeEN: "Shau Kei Wan", coordinate: .init(latitude: 22.2800, longitude: 114.2280)),
        StationCoordinate(placeTC: "九龍城", placeEN: "Kowloon City", coordinate: .init(latitude: 22.3280, longitude: 114.1910)),
        StationCoordinate(placeTC: "跑馬地", placeEN: "Happy Valley", coordinate: .init(latitude: 22.2700, longitude: 114.1830)),
        StationCoordinate(placeTC: "黃大仙", placeEN: "Wong Tai Sin", coordinate: .init(latitude: 22.3410, longitude: 114.1950)),
        StationCoordinate(placeTC: "赤柱", placeEN: "Stanley", coordinate: .init(latitude: 22.2180, longitude: 114.2140)),
        StationCoordinate(placeTC: "觀塘", placeEN: "Kwun Tong", coordinate: .init(latitude: 22.3100, longitude: 114.2250)),
        StationCoordinate(placeTC: "深水埗", placeEN: "Sham Shui Po", coordinate: .init(latitude: 22.3300, longitude: 114.1600)),
        StationCoordinate(placeTC: "啟德跑道公園", placeEN: "Kai Tak Runway Park", coordinate: .init(latitude: 22.3080, longitude: 114.2150)),
        StationCoordinate(placeTC: "元朗公園", placeEN: "Yuen Long Park", coordinate: .init(latitude: 22.4440, longitude: 114.0280)),
        StationCoordinate(placeTC: "大美督", placeEN: "Tai Mei Tuk", coordinate: .init(latitude: 22.4730, longitude: 114.2340))
    ]
}
