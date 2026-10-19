import SwiftUI
import SwiftData
import MapKit

struct DashboardFavoriteStationsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: [SortDescriptor(\FavoriteStation.sortOrder), SortDescriptor(\FavoriteStation.stationID)])
    private var favorites: [FavoriteStation]
    let section: WeatherDashboardSection<RegionWeatherForecast>
    let isRefreshing: Bool
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.text("favorites_title")).font(.headline)
            if favorites.isEmpty {
                Text(settings.text("favorites_empty_message")).font(.subheadline).foregroundStyle(.secondary)
            } else {
                if section.isLoading && section.value == nil { ProgressView(settings.text("weather_loading")) }
                if section.errorMessage != nil {
                    Text(settings.text("favorites_weather_error")).font(.subheadline)
                    Button(settings.text("weather_retry"), action: retry).disabled(isRefreshing)
                }
                if section.value != nil && section.errorMessage != nil {
                    Text(settings.text("weather_previous_data")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(favorites) { favorite in
                    let station = StationCoordinateStore.station(withID: favorite.stationID)
                    let name = station?.name(lang: settings.apiLanguageCode) ?? favorite.stationID
                    let reading = station?.temperature(in: section.value)
                    NavigationLink {
                        FavoriteStationDetailView(stationID: favorite.stationID, label: favorite.label)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(favorite.label.isEmpty ? name : favorite.label).font(.subheadline.bold())
                            if !favorite.label.isEmpty { Text(name).font(.caption).foregroundStyle(.secondary) }
                            HStack(alignment: .firstTextBaseline) {
                                Text(settings.measurement(reading?.value, unit: reading?.unit)).font(.title2)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }
                            if reading?.value != nil { WeatherUpdateView(timestamp: section.value?.temperature?.recordTime) }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            NavigationLink(settings.text(favorites.isEmpty ? "favorites_choose_station" : "favorites_manage")) {
                FavoriteStationsView()
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct FavoriteStationDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    let stationID: String
    let label: String
    @StateObject private var viewModel = WeatherViewModel()

    private var report: RegionWeatherForecast? {
        viewModel.lastChecked == nil ? nil : viewModel.regionWeatherForecast
    }
    private var isPrevious: Bool { viewModel.isLoading || viewModel.errorMessage != nil }

    private var station: StationCoordinate? { StationCoordinateStore.station(withID: stationID) }
    private var name: String { station?.name(lang: settings.apiLanguageCode) ?? stationID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(name).font(.title2.bold())
                WeatherStatusView(viewModel: viewModel) { Task { await refresh() } }
                if isPrevious && report != nil {
                    Text(settings.text("weather_previous_data")).font(.caption).foregroundStyle(.secondary)
                }
                let reading = station?.temperature(in: report)
                Text(settings.measurement(reading?.value, unit: reading?.unit)).font(.largeTitle)
                if reading?.value != nil { WeatherUpdateView(timestamp: report?.temperature?.recordTime) }
                if let station {
                    Map(initialPosition: .region(MKCoordinateRegion(center: station.coordinate,
                                                                  latitudinalMeters: 6000, longitudinalMeters: 6000))) {
                        Marker(name, coordinate: station.coordinate)
                    }
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("\(settings.text("favorites_station_map")): \(name)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(label.isEmpty ? name : label)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
    }

    private func refresh() async {
        await viewModel.loadCurrentReport(lang: settings.apiLanguageCode)
    }
}
