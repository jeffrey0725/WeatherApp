import SwiftUI
import UIKit

struct NearbyWeatherView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @ObservedObject var location: LocationManager
    let section: WeatherDashboardSection<RegionWeatherForecast>
    let onLocate: () -> Void
    let onSelect: (RegionalStationSelection) -> Void
    let onShowMap: (StationCoordinate) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 14) {
                Label(settings.text("nearby_title"), systemImage: "location.fill").font(.headline)
                Text(settings.text("nearby_description")).font(.subheadline).foregroundStyle(.secondary)
                Button(action: onLocate) {
                    HStack {
                        if location.isLocating { ProgressView() }
                        Text(settings.text(location.isLocating ? "nearby_locating" : "nearby_find"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(location.isLocating || section.isLoading)

                if location.isLocating {
                    Button(settings.text("nearby_cancel")) { location.cancel() }
                        .frame(minHeight: 44)
                } else if let failure = location.failure {
                    Text(settings.text(failure.titleKey)).font(.subheadline)
                    if failure == .denied {
                        Button(settings.text("nearby_settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .frame(minHeight: 44)
                    }
                } else if let fix = location.location {
                    let state = NearbyWeatherState(location: fix, now: context.date, section: section)
                    switch state {
                    case .expired: message("nearby_location_expired")
                    case .loading: message("nearby_waiting_weather")
                    case .unavailable: message("nearby_weather_unavailable")
                    case .noNearby: message("nearby_no_station")
                    case .match(let match):
                        matchDetails(match)
                        if fix.horizontalAccuracy > 1000 { message("nearby_approximate_location") }
                        Text("\(settings.text("nearby_location_checked")): \(settings.timestamp(fix.timestamp))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func message(_ key: String) -> some View {
        Text(settings.text(key)).font(.subheadline).foregroundStyle(.secondary)
    }

    private func matchDetails(_ match: NearbyWeatherMatch) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text(settings.text("nearby_station")).font(.caption).foregroundStyle(.secondary)
            Text(match.observation.station.name(lang: settings.apiLanguageCode)).font(.title3.bold())
            Text(settings.measurement(match.observation.reading?.value, unit: match.observation.reading?.unit))
                .font(.largeTitle.bold()).monospacedDigit()
            Text("\(settings.text("nearby_distance")): \(NearbyWeatherFormatting.distance(match.distanceMeters, locale: settings.locale))")
                .font(.subheadline)
            Text("\(settings.text("weather_observed_at")): \(settings.timestamp(section.value?.temperature?.recordTime) ?? settings.text("weather_unavailable"))")
                .font(.caption).foregroundStyle(.secondary)
            Button(settings.text("weather_read_details")) {
                onSelect(match.observation.selection(lang: settings.apiLanguageCode,
                         observationTime: section.value?.temperature?.recordTime))
            }
            .buttonStyle(.bordered).frame(minHeight: 44)
            Button(settings.text("nearby_show_map")) { onShowMap(match.observation.station) }
                .buttonStyle(.bordered).frame(minHeight: 44)
        }
    }
}
