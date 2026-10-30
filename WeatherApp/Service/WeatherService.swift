import Foundation

enum WeatherServiceError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppLocalization.text("weather_error_url")
        case .invalidResponse, .httpStatus:
            return AppLocalization.text("weather_error_response")
        case .invalidData:
            return AppLocalization.text("weather_error_data")
        }
    }

    static func message(for error: Error, lang: String, bundle: Bundle = .main) -> String {
        let key: String
        switch error {
        case WeatherServiceError.invalidURL: key = "weather_error_url"
        case WeatherServiceError.invalidData: key = "weather_error_data"
        case is WeatherServiceError: key = "weather_error_response"
        case let network as URLError where network.code == .notConnectedToInternet: key = "weather_error_connection"
        case let network as URLError where network.code == .timedOut: key = "weather_error_timeout"
        default: key = "weather_error_response"
        }
        return AppLocalization.text(key, locale: AppLanguage.forAPI(lang).locale, bundle: bundle)
    }
}

struct WeatherService {
    private let session: URLSession
    private let baseURL: String

    private static let liveSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession? = nil,
         baseURL: String = "https://data.weather.gov.hk/weatherAPI/opendata/weather.php") {
        self.session = session ?? Self.liveSession
        self.baseURL = baseURL
    }

    func localForecast(lang: String) async throws -> LocalWeatherForecast {
        try await fetch(.localWeatherForecast, lang: lang)
    }

    func nineDayForecast(lang: String) async throws -> NineDayWeatherForecast {
        try await fetch(.nineDayWeatherForecast, lang: lang)
    }

    func currentReport(lang: String) async throws -> RegionWeatherForecast {
        try await fetch(.currentWeatherReport, lang: lang)
    }

    func warningSummary(lang: String) async throws -> WeatherWarningSummary {
        try await fetch(.weatherWarningSummary, lang: lang)
    }

    func warningInformation(lang: String) async throws -> WeatherWarningInformation {
        try await fetch(.weatherWarningInformation, lang: lang)
    }

    func specialTips(lang: String) async throws -> SpecialWeatherTips {
        try await fetch(.specialWeatherTips, lang: lang)
    }

    func hourlyRainfall(lang: String) async throws -> HourlyRainfallReport {
        try await fetch(endpoint: "hourlyRainfall.php", dataType: nil, lang: lang)
    }

    func solarTimes(on date: Date) async throws -> SolarDay {
        let response: SolarTimesResponse = try await fetch(endpoint: "opendata.php",
                                                           queryItems: Self.dailyQuery("SRS", on: date))
        guard response.days.count == 1, let day = response.days.first,
              day.date == SolarDay.calendar.startOfDay(for: date) else {
            throw WeatherServiceError.invalidData
        }
        return day
    }

    func moonTimes(on date: Date) async throws -> MoonDay {
        let response: MoonTimesResponse = try await fetch(endpoint: "opendata.php",
                                                          queryItems: Self.dailyQuery("MRS", on: date))
        guard response.days.count == 1, let day = response.days.first,
              day.date == SolarDay.calendar.startOfDay(for: date) else {
            throw WeatherServiceError.invalidData
        }
        return day
    }

    func tideTimes(at station: TideStation, on date: Date) async throws -> TideDay {
        let response: TideTimesResponse = try await fetch(endpoint: "opendata.php", queryItems:
            Self.dailyQuery("HLT", station: station.id, on: date))
        let parts = SolarDay.calendar.dateComponents([.year, .month, .day], from: date)
        // An empty tide list for a date is bad data, not a day without tides.
        guard response.rows.count == 1, let row = response.rows.first,
              row.month == parts.month, row.day == parts.day, !row.readings.isEmpty,
              let year = parts.year else {
            throw WeatherServiceError.invalidData
        }
        return try row.tideDay(year: year)
    }

    func warningReport(lang: String) async throws -> WeatherWarningReport {
        async let summary = warningSummary(lang: lang)
        async let information = warningInformation(lang: lang)
        async let tips = specialTips(lang: lang)
        // Publish a warning snapshot only when all three requests succeed.
        return try await WeatherWarningReport(summary: summary, information: information, tips: tips)
    }

    // The opendata.php tables are requested one Hong Kong date at a time and carry no language.
    private static func dailyQuery(_ dataType: String, station: String? = nil, on date: Date) -> [URLQueryItem] {
        let parts = SolarDay.calendar.dateComponents([.year, .month, .day], from: date)
        var items = [URLQueryItem(name: "dataType", value: dataType)]
        if let station { items.append(URLQueryItem(name: "station", value: station)) }
        items += [
            URLQueryItem(name: "year", value: String(parts.year!)),
            URLQueryItem(name: "month", value: String(parts.month!)),
            URLQueryItem(name: "day", value: String(parts.day!)),
            URLQueryItem(name: "rformat", value: "json")
        ]
        return items
    }

    private func fetch<T: Decodable>(_ type: WeatherDataType, lang: String) async throws -> T {
        try await fetch(endpoint: nil, dataType: type.rawValue, lang: lang)
    }

    private func fetch<T: Decodable>(endpoint: String?, dataType: String?, lang: String) async throws -> T {
        var queryItems = dataType.map { [URLQueryItem(name: "dataType", value: $0)] } ?? []
        queryItems.append(URLQueryItem(name: "lang", value: lang))
        return try await fetch(endpoint: endpoint, queryItems: queryItems)
    }

    private func fetch<T: Decodable>(endpoint: String?, queryItems: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: baseURL),
              components.scheme == "https", components.host != nil else {
            throw WeatherServiceError.invalidURL
        }
        if let endpoint {
            components.path = (components.path as NSString).deletingLastPathComponent + "/" + endpoint
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw WeatherServiceError.invalidURL }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw WeatherServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw WeatherServiceError.httpStatus(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeatherServiceError.invalidData
        }
    }
}
