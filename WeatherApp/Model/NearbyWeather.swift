import Foundation
import CoreLocation

enum LocationFixPolicy {
    static func isValid(_ location: CLLocation, at now: Date) -> Bool {
        let age = now.timeIntervalSince(location.timestamp)
        return CLLocationCoordinate2DIsValid(location.coordinate)
            && location.coordinate.latitude.isFinite && location.coordinate.longitude.isFinite
            && location.horizontalAccuracy.isFinite && location.horizontalAccuracy >= 0
            && age >= -5 && age <= 60
    }
    static func isExpired(_ location: CLLocation, at now: Date) -> Bool {
        let age = now.timeIntervalSince(location.timestamp)
        return age < -5 || age > 300
    }
}

struct NearbyWeatherMatch: Identifiable {
    let observation: RegionalStationObservation
    let distanceMeters: CLLocationDistance
    var id: String { observation.id }

    static func nearest(in report: RegionWeatherForecast, to location: CLLocation,
                        catalog: [StationCoordinate] = StationCoordinateStore.stationCoordinates,
                        maximumDistance: CLLocationDistance = 50_000) -> NearbyWeatherMatch? {
        guard CLLocationCoordinate2DIsValid(location.coordinate), maximumDistance.isFinite,
              maximumDistance >= 0 else { return nil }
        return catalog.compactMap { station -> NearbyWeatherMatch? in
            let observation = RegionalStationObservation(station: station, reading: station.temperature(in: report))
            guard observation.temperatureForSorting != nil,
                  CLLocationCoordinate2DIsValid(station.coordinate) else { return nil }
            let position = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
            let distance = location.distance(from: position)
            guard distance.isFinite, distance >= 0, distance <= maximumDistance else { return nil }
            return NearbyWeatherMatch(observation: observation, distanceMeters: distance)
        }.min {
            $0.distanceMeters == $1.distanceMeters ? $0.id < $1.id : $0.distanceMeters < $1.distanceMeters
        }
    }
}

enum NearbyWeatherState {
    case expired, loading, unavailable, noNearby
    case match(NearbyWeatherMatch)

    init(location: CLLocation, now: Date, section: WeatherDashboardSection<RegionWeatherForecast>) {
        if LocationFixPolicy.isExpired(location, at: now) { self = .expired }
        else if section.isLoading { self = .loading }
        else if section.errorMessage != nil || section.lastChecked == nil { self = .unavailable }
        else if let report = section.value {
            if let match = NearbyWeatherMatch.nearest(in: report, to: location) { self = .match(match) }
            else { self = .noNearby }
        } else { self = .unavailable }
    }
}

enum NearbyWeatherFormatting {
    static func distance(_ meters: CLLocationDistance, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        formatter.numberFormatter.locale = locale
        formatter.numberFormatter.maximumFractionDigits = meters >= 1000 ? 1 : 0
        let measurement = Measurement(value: meters >= 1000 ? meters / 1000 : meters,
                                      unit: meters >= 1000 ? UnitLength.kilometers : .meters)
        return formatter.string(from: measurement)
    }
}
