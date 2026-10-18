import Foundation

enum RainfallStationCatalog {
    // Search aliases from the English/Traditional Chinese hourly rainfall feeds.
    // These IDs belong to the rainfall dataset, not the temperature catalog.
    static let names: [String: (english: String, chinese: String)] = [
        "RF001": ("Lau Fau Shan", "流浮山"),
        "RF002": ("Wetland Park", "濕地公園"),
        "N12": ("Shui Pin Wai", "水邊圍"),
        "RF003": ("Shek Kong", "石崗"),
        "RF004": ("Tai Mei Tuk", "大美督"),
        "RF005": ("Tai Po Market", "大埔墟"),
        "RF006": ("Pak Tam Chung", "北潭涌"),
        "RF007": ("Kau Sai Chau", "滘西洲"),
        "N15": ("Sai Kung", "西貢"),
        "RF008": ("Tseung Kwan O", "將軍澳"),
        "RF009": ("Clear Water Bay", "清水灣"),
        "RF010": ("Waglan Island", "橫瀾島"),
        "RF011": ("Cheung Chau", "長洲"),
        "RF012": ("Peng Chau", "坪洲"),
        "RF013": ("Ngong Ping", "昂坪"),
        "RF014": ("Hong Kong International Airport", "香港國際機場"),
        "RF015": ("Ta Kwu Ling", "打鼓嶺"),
        "RF016": ("Sheung Shui", "上水"),
        "RF017": ("Tai Lung", "大隴"),
        "RF018": ("Tsuen Wan Ho Koon", "荃灣可觀"),
        "RF019": ("Tuen Mun", "屯門"),
        "RF020": ("Sha Tin", "沙田"),
        "RF021": ("Cheung Ching", "長青"),
        "RF022": ("Sham Shui Po", "深水埗"),
        "RF023": ("Hong Kong Observatory", "香港天文台"),
        "RF024": ("King's Park", "京士柏"),
        "K02": ("Broadcast Drive", "廣播道"),
        "RF025": ("Kai Tak", "啟德"),
        "K09": ("San Po Kong", "新蒲崗"),
        "K03": ("Kwun Tong", "觀塘"),
        "RF026": ("Shau Kei Wan", "筲箕灣"),
        "RF027": ("Happy Valley", "跑馬地"),
        "RF028": ("The Peak", "山頂"),
        "H17": ("Magazine Gap", "馬己仙峽"),
        "H15": ("Stanley", "赤柱"),
        "H24": ("Wong Chuk Hang", "黃竹坑")
    ]

    // WGS84 points from HKO’s CSDI hourlyRainfall layer. The data_url filename,
    // NOT that layer’s automaticWeatherStationID, identifies the hourly API station.
    // Verified against all 36 English API names on 2026-10-18. See docs/RAINFALL_STATIONS.md.
    struct Location: Equatable {
        let latitude: Double
        let longitude: Double
    }

    static let locations: [String: Location] = [
        "RF001": Location(latitude: 22.46888889, longitude: 113.98361111),
        "RF002": Location(latitude: 22.46666667, longitude: 114.00888889),
        "N12": Location(latitude: 22.44614626, longitude: 114.02096340),
        "RF003": Location(latitude: 22.43611111, longitude: 114.08472222),
        "RF004": Location(latitude: 22.47527778, longitude: 114.23750000),
        "RF005": Location(latitude: 22.44555556, longitude: 114.17166667),
        "RF006": Location(latitude: 22.40277778, longitude: 114.32305556),
        "RF007": Location(latitude: 22.37027778, longitude: 114.31250000),
        "N15": Location(latitude: 22.38261834, longitude: 114.27028350),
        "RF008": Location(latitude: 22.31583333, longitude: 114.25555556),
        "RF009": Location(latitude: 22.26333333, longitude: 114.29972222),
        "RF010": Location(latitude: 22.18222222, longitude: 114.30333333),
        "RF011": Location(latitude: 22.20111111, longitude: 114.02666667),
        "RF012": Location(latitude: 22.29111111, longitude: 114.04333333),
        "RF013": Location(latitude: 22.25555556, longitude: 113.91138890),
        "RF014": Location(latitude: 22.30944444, longitude: 113.92194444),
        "RF015": Location(latitude: 22.52861111, longitude: 114.15666667),
        "RF016": Location(latitude: 22.50194444, longitude: 114.11111111),
        "RF017": Location(latitude: 22.48472222, longitude: 114.11750000),
        "RF018": Location(latitude: 22.38361111, longitude: 114.10777778),
        "RF019": Location(latitude: 22.38583333, longitude: 113.96416667),
        "RF020": Location(latitude: 22.40250000, longitude: 114.21000000),
        "RF021": Location(latitude: 22.34805556, longitude: 114.10916667),
        "RF022": Location(latitude: 22.33583333, longitude: 114.13694444),
        "RF023": Location(latitude: 22.30194444, longitude: 114.17416667),
        "RF024": Location(latitude: 22.31194444, longitude: 114.17277778),
        "K02": Location(latitude: 22.34299050, longitude: 114.17892222),
        "RF025": Location(latitude: 22.30972222, longitude: 114.21333333),
        "K09": Location(latitude: 22.33257776, longitude: 114.19570500),
        "K03": Location(latitude: 22.31861151, longitude: 114.22461660),
        "RF026": Location(latitude: 22.28166667, longitude: 114.23611111),
        "RF027": Location(latitude: 22.27055556, longitude: 114.18361111),
        "RF028": Location(latitude: 22.26416667, longitude: 114.15500000),
        "H17": Location(latitude: 22.27173028, longitude: 114.16407860),
        "H15": Location(latitude: 22.21557006, longitude: 114.21565990),
        "H24": Location(latitude: 22.25126785, longitude: 114.17355890)
    ]
}
