import Foundation

struct TideStation: Identifiable, Equatable {
    let id: String
    let english: String
    let chinese: String

    func name(lang: String) -> String { lang == "en" ? english : chinese }
}

// The 14 stations HKO documents for the HHOT and HLT datasets. Codes and the English and Traditional
// Chinese names come from the English and Traditional Chinese editions of the HKO Open Data API
// documentation; all 14 returned data from the live HLT endpoint on 2026-10-30. These codes belong to
// the tide dataset and are unrelated to the temperature and rainfall station IDs.
enum TideStationCatalog {
    /// Quarry Bay, on Victoria Harbour.
    static let defaultStationID = "QUB"

    static let stations: [TideStation] = [
        TideStation(id: "CCH", english: "Cheung Chau", chinese: "長洲"),
        TideStation(id: "CLK", english: "Chek Lap Kok", chinese: "赤鱲角"),
        TideStation(id: "CMW", english: "Chi Ma Wan", chinese: "芝麻灣"),
        TideStation(id: "KCT", english: "Kwai Chung", chinese: "葵涌"),
        TideStation(id: "KLW", english: "Ko Lau Wan", chinese: "高流灣"),
        TideStation(id: "LOP", english: "Lok On Pai", chinese: "樂安排"),
        TideStation(id: "MWC", english: "Ma Wan", chinese: "馬灣"),
        TideStation(id: "QUB", english: "Quarry Bay", chinese: "鰂魚涌"),
        TideStation(id: "SPW", english: "Shek Pik", chinese: "石壁"),
        TideStation(id: "TAO", english: "Tai O", chinese: "大澳"),
        TideStation(id: "TBT", english: "Tsim Bei Tsui", chinese: "尖鼻咀"),
        TideStation(id: "TMW", english: "Tai Miu Wan", chinese: "大廟灣"),
        TideStation(id: "TPK", english: "Tai Po Kau", chinese: "大埔滘"),
        TideStation(id: "WAG", english: "Waglan Island", chinese: "橫瀾島")
    ]

    static func station(withID id: String) -> TideStation? {
        stations.first { $0.id == id }
    }

    static var defaultStation: TideStation {
        station(withID: defaultStationID) ?? stations[0]
    }

    static func sortedStations(lang: String) -> [TideStation] {
        stations.sorted { $0.name(lang: lang).localizedStandardCompare($1.name(lang: lang)) == .orderedAscending }
    }
}
