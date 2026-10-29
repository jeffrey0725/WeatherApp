import SwiftUI
import SwiftData

struct RegionalWeatherExplorerView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = WeatherViewModel()
    @StateObject private var location = LocationManager()
    @Environment(\.scenePhase) private var scenePhase
    @Query private var favorites: [FavoriteStation]
    @State private var query = ""
    @State private var filter: RegionalStationFilter = .all
    @State private var displayMode: RegionalExplorerDisplayMode = .map
    @State private var sortOrder: RegionalStationSort = .name
    @State private var selectedStation: RegionalStationSelection?
    @State private var isWide = false

    private var favoriteIDs: Set<String> { Set(favorites.map(\.stationID)) }
    private var results: RegionalWeatherExplorerResults {
        RegionalWeatherExplorerResults(report: viewModel.regionWeatherForecast, query: query,
                                       filter: filter, favoriteIDs: favoriteIDs, lang: settings.apiLanguageCode)
    }
    private var weatherSection: WeatherDashboardSection<RegionWeatherForecast> {
        WeatherDashboardSection(value: viewModel.lastChecked == nil ? nil : viewModel.regionWeatherForecast,
                                isLoading: viewModel.isLoading, errorMessage: viewModel.errorMessage,
                                lastChecked: viewModel.lastChecked)
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(settings.text("explorer_description"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    NearbyWeatherView(location: location, section: weatherSection, onLocate: findNearby,
                                      onSelect: { selectedStation = $0 }, onShowMap: { station in
                        query = station.name(lang: settings.apiLanguageCode)
                        filter = .all
                        displayMode = .map
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation { scroll.scrollTo("regional-map", anchor: .top) }
                        }
                    })
                    Picker(settings.text("explorer_filter"), selection: $filter) {
                        ForEach(RegionalStationFilter.allCases) { option in
                            Text(settings.text(option.titleKey)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(settings.text("explorer_filter"))

                    if !isWide {
                        Picker(settings.text("explorer_display_mode"), selection: $displayMode) {
                            ForEach(RegionalExplorerDisplayMode.allCases) { mode in
                                Text(settings.text(mode.titleKey)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(settings.text("explorer_display_mode"))
                    }

                    WeatherStatusView(viewModel: viewModel, retry: retry)
                    if let checked = viewModel.lastChecked {
                        if viewModel.isLoading || viewModel.errorMessage != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settings.text("weather_previous_data"))
                                Text("\(settings.text("weather_last_checked")): \(settings.timestamp(checked))")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        observations
                    }

                    Text(settings.text("weather_data_source"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onWideLayoutChange { isWide = $0 }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.text("explorer_title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.text("favorites_search"))
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $selectedStation) { selection in
            RegionalWeatherBottomSheetView(station: selection.station, observationTime: selection.observationTime)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink { RegionWeatherInfoView() } label: {
                    Label(settings.text("region_weather_title"), systemImage: "info.circle")
                }
                Button(action: retry) { RefreshToolbarLabel(isLoading: viewModel.isLoading) }
                    .disabled(viewModel.isLoading)
            }
            .keepVisibleLongest()
        }
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { location.cancel() }
        }
        .onDisappear { location.cancel() }
    }

    private var observations: some View {
        let results = results
        let readings = results.mapReadings(lang: settings.apiLanguageCode)
        // A wide window shows the map and the list together; a narrow one switches between them.
        let showsMap = isWide || displayMode == .map
        let showsList = isWide || displayMode == .list
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(settings.text("explorer_station_count")): \(showsList ? results.stations.count : readings.count)").font(.headline)
                Spacer()
                NavigationLink(settings.text("favorites_manage")) { FavoriteStationsView() }
                    .font(.subheadline)
            }
            if let time = settings.timestamp(viewModel.regionWeatherForecast.temperature?.recordTime) {
                Text("\(settings.text("weather_observed_at")): \(time)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Preserve the camera while switching views. The explorer owns the
            // sheet, including when removing the final favorite empties the list.
            layout {
                VStack(alignment: .leading, spacing: 12) {
                    RegionMapView(stations: readings,
                                  observationTime: viewModel.regionWeatherForecast.temperature?.recordTime,
                                  selectionID: selectedStation?.id, onSelect: { selectedStation = $0 })
                        .overlay {
                            if readings.isEmpty && showsMap && (!isWide || !results.stations.isEmpty) { emptyResults(results) }
                        }
                        .frame(height: showsMap ? (isWide ? 600 : 500) : 0)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .opacity(showsMap ? 1 : 0)
                        .allowsHitTesting(showsMap)
                        .accessibilityHidden(!showsMap)
                        .id("regional-map")
                    if showsMap && !readings.isEmpty {
                        Text(settings.text("explorer_map_help")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 12) {
                    if showsList {
                        Picker(settings.text("explorer_sort"), selection: $sortOrder) {
                            ForEach(RegionalStationSort.allCases) { order in
                                Text(settings.text(order.titleKey)).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: 44)
                        .accessibilityLabel(settings.text("explorer_sort"))

                        if results.stations.isEmpty {
                            emptyResults(results).frame(minHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            Text(settings.text("explorer_list_help")).font(.caption).foregroundStyle(.secondary)
                            RegionalStationListView(stations: results.listStations(sort: sortOrder, lang: settings.apiLanguageCode),
                                                    favoriteIDs: favoriteIDs,
                                                    observationTime: viewModel.regionWeatherForecast.temperature?.recordTime,
                                                    onSelect: { selectedStation = $0 })
                        }
                    }
                }
                .padding(.top, !isWide && showsList ? 12 : 0)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }.layoutIdentifier(isWide: isWide)
            if results.unavailableCount > 0 && (showsList || !readings.isEmpty) {
                Text("\(settings.text("explorer_unavailable_count")): \(results.unavailableCount)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func emptyResults(_ results: RegionalWeatherExplorerResults) -> some View {
        let noFavorites = filter == .favorites && favoriteIDs.isEmpty
        let title = noFavorites ? "explorer_no_favorites" :
            (results.stations.isEmpty ? "explorer_no_matches" : "explorer_no_readings")
        let description = noFavorites ? "favorites_empty_message" :
            (results.stations.isEmpty ? "explorer_search_help" : "explorer_readings_help")
        return ContentUnavailableView {
            Label(settings.text(title), systemImage: noFavorites ? "star" : "mappin.slash")
        } description: {
            Text(settings.text(description))
        } actions: {
            if noFavorites {
                NavigationLink(settings.text("favorites_choose_station")) { FavoriteStationsView() }
            } else if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(settings.text("explorer_clear_search")) { query = "" }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.groupedCard)
    }

    private func retry() { Task { await refresh() } }
    private func refresh() async { await viewModel.loadCurrentReport(lang: settings.apiLanguageCode) }
    private func findNearby() {
        Task { @MainActor in
            async let fix: Void = location.locate()
            async let weather: Void = refresh()
            _ = await (fix, weather)
        }
    }
}

#Preview {
    NavigationStack { RegionalWeatherExplorerView() }
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .environmentObject(AppSettings.preview)
}
