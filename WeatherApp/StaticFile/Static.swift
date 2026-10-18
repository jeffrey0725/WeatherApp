//
//  Static.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/3/2026.
//

import Foundation
import CoreLocation

struct StationCoordinate: Identifiable {
    let id: String
    let placeTC: String
    let placeEN: String
    let coordinate: CLLocationCoordinate2D

    func name(lang: String) -> String { lang == "en" ? placeEN : placeTC }

    func temperature(in report: RegionWeatherForecast?) -> TemperatureData? {
        report?.temperature?.data?.first { $0.place == placeEN || $0.place == placeTC }
    }
}

struct StationCoordinateStore {
    static func station(withID id: String) -> StationCoordinate? {
        stationCoordinates.first { $0.id == id }
    }

    static func stations(matching query: String, lang: String) -> [StationCoordinate] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return stationCoordinates.filter {
            query.isEmpty || $0.placeEN.localizedStandardContains(query) || $0.placeTC.localizedStandardContains(query)
        }.sorted { $0.name(lang: lang).localizedStandardCompare($1.name(lang: lang)) == .orderedAscending }
    }

    static let stationCoordinates: [StationCoordinate] = [
        StationCoordinate(id: "king-s-park", placeTC: "京士柏", placeEN: "King's Park", coordinate: .init(latitude: 22.3195, longitude: 114.1751)),
        StationCoordinate(id: "hong-kong-observatory", placeTC: "香港天文台", placeEN: "Hong Kong Observatory", coordinate: .init(latitude: 22.3019, longitude: 114.1740)),
        StationCoordinate(id: "wong-chuk-hang", placeTC: "黃竹坑", placeEN: "Wong Chuk Hang", coordinate: .init(latitude: 22.2470, longitude: 114.1700)),
        StationCoordinate(id: "ta-kwu-ling", placeTC: "打鼓嶺", placeEN: "Ta Kwu Ling", coordinate: .init(latitude: 22.5280, longitude: 114.1470)),
        StationCoordinate(id: "lau-fau-shan", placeTC: "流浮山", placeEN: "Lau Fau Shan", coordinate: .init(latitude: 22.4690, longitude: 113.9970)),
        StationCoordinate(id: "tai-po", placeTC: "大埔", placeEN: "Tai Po", coordinate: .init(latitude: 22.4500, longitude: 114.1690)),
        StationCoordinate(id: "sha-tin", placeTC: "沙田", placeEN: "Sha Tin", coordinate: .init(latitude: 22.3830, longitude: 114.1880)),
        StationCoordinate(id: "tuen-mun", placeTC: "屯門", placeEN: "Tuen Mun", coordinate: .init(latitude: 22.3910, longitude: 113.9710)),
        StationCoordinate(id: "tseung-kwan-o", placeTC: "將軍澳", placeEN: "Tseung Kwan O", coordinate: .init(latitude: 22.3080, longitude: 114.2600)),
        StationCoordinate(id: "sai-kung", placeTC: "西貢", placeEN: "Sai Kung", coordinate: .init(latitude: 22.3810, longitude: 114.2710)),
        StationCoordinate(id: "cheung-chau", placeTC: "長洲", placeEN: "Cheung Chau", coordinate: .init(latitude: 22.2080, longitude: 114.0260)),
        StationCoordinate(id: "chek-lap-kok", placeTC: "赤鱲角", placeEN: "Chek Lap Kok", coordinate: .init(latitude: 22.3080, longitude: 113.9185)),
        StationCoordinate(id: "tsing-yi", placeTC: "青衣", placeEN: "Tsing Yi", coordinate: .init(latitude: 22.3530, longitude: 114.1070)),
        StationCoordinate(id: "shek-kong", placeTC: "石崗", placeEN: "Shek Kong", coordinate: .init(latitude: 22.4360, longitude: 114.0840)),
        StationCoordinate(id: "tsuen-wan-ho-koon", placeTC: "荃灣可觀", placeEN: "Tsuen Wan Ho Koon", coordinate: .init(latitude: 22.3836, longitude: 114.1040)),
        StationCoordinate(id: "tsuen-wan-shing-mun-valley", placeTC: "荃灣城門谷", placeEN: "Tsuen Wan Shing Mun Valley", coordinate: .init(latitude: 22.3750, longitude: 114.1230)),
        StationCoordinate(id: "hong-kong-park", placeTC: "香港公園", placeEN: "Hong Kong Park", coordinate: .init(latitude: 22.2776, longitude: 114.1617)),
        StationCoordinate(id: "shau-kei-wan", placeTC: "筲箕灣", placeEN: "Shau Kei Wan", coordinate: .init(latitude: 22.2800, longitude: 114.2280)),
        StationCoordinate(id: "kowloon-city", placeTC: "九龍城", placeEN: "Kowloon City", coordinate: .init(latitude: 22.3280, longitude: 114.1910)),
        StationCoordinate(id: "happy-valley", placeTC: "跑馬地", placeEN: "Happy Valley", coordinate: .init(latitude: 22.2700, longitude: 114.1830)),
        StationCoordinate(id: "wong-tai-sin", placeTC: "黃大仙", placeEN: "Wong Tai Sin", coordinate: .init(latitude: 22.3410, longitude: 114.1950)),
        StationCoordinate(id: "stanley", placeTC: "赤柱", placeEN: "Stanley", coordinate: .init(latitude: 22.2180, longitude: 114.2140)),
        StationCoordinate(id: "kwun-tong", placeTC: "觀塘", placeEN: "Kwun Tong", coordinate: .init(latitude: 22.3100, longitude: 114.2250)),
        StationCoordinate(id: "sham-shui-po", placeTC: "深水埗", placeEN: "Sham Shui Po", coordinate: .init(latitude: 22.3300, longitude: 114.1600)),
        StationCoordinate(id: "kai-tak-runway-park", placeTC: "啟德跑道公園", placeEN: "Kai Tak Runway Park", coordinate: .init(latitude: 22.3080, longitude: 114.2150)),
        StationCoordinate(id: "yuen-long-park", placeTC: "元朗公園", placeEN: "Yuen Long Park", coordinate: .init(latitude: 22.4440, longitude: 114.0280)),
        StationCoordinate(id: "tai-mei-tuk", placeTC: "大美督", placeEN: "Tai Mei Tuk", coordinate: .init(latitude: 22.4730, longitude: 114.2340))
    ]
}
