import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = WeatherDashboardViewModel()
    @StateObject private var solarTimes = SolarTimesViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.text("weather_hong_kong")).font(.title2.bold())
                        Text(settings.text("weather_data_source"))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    WeatherDashboardSectionView(title: "weather_conditions", section: viewModel.current, isRefreshing: viewModel.isLoading, retry: retry) { report in
                        DashboardConditionsView(report: report)
                    }
                    WeatherDashboardSectionView(title: "weather_warnings_title", section: viewModel.warnings, isRefreshing: viewModel.isLoading, retry: retry) { report in
                        DashboardWarningsView(report: report, lastChecked: viewModel.warnings.lastChecked,
                                              isPrevious: viewModel.warnings.errorMessage != nil || viewModel.warnings.isLoading)
                    }
                    DashboardFavoriteStationsView(section: viewModel.current, isRefreshing: viewModel.isLoading, retry: retry)
                    DashboardSolarTimesView(viewModel: solarTimes, isRefreshing: isRefreshing, retry: retry)
                    WeatherDashboardSectionView(title: "local_weather_title", section: viewModel.local, isRefreshing: viewModel.isLoading, retry: retry) { forecast in
                        DashboardLocalForecastView(forecast: forecast)
                    }
                    WeatherDashboardSectionView(title: "weather_next_three_days", section: viewModel.forecast, isRefreshing: viewModel.isLoading, retry: retry) { forecast in
                        DashboardForecastPreviewView(forecast: forecast)
                    }

                    NavigationLink {
                        RegionalWeatherExplorerView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settings.text("weather_regional_shortcut")).font(.headline)
                                Text(settings.text("weather_regional_description"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HourlyRainfallView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cloud.rain.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settings.text("rainfall_title")).font(.headline)
                                Text(settings.text("rainfall_shortcut_description"))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.bold())
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    // Detail screens remain accessible even if a dashboard request fails.
                    NavigationLink(settings.text("weather_browse_reports")) {
                        List {
                            NavigationLink(settings.text("favorites_title")) { FavoriteStationsView() }
                            NavigationLink(settings.text("local_weather_title")) { LocalWeatherInfoView() }
                            NavigationLink(settings.text("nine_weather_title")) { NineDayWeatherInfoView() }
                            NavigationLink(settings.text("region_weather_title")) { RegionWeatherInfoView() }
                            NavigationLink(settings.text("rainfall_title")) { HourlyRainfallView() }
                            NavigationLink(settings.text("weather_warnings_title")) { WeatherWarningsView() }
                        }
                        .navigationTitle(settings.text("weather_browse_reports"))
                    }
                    .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.text("weather_today"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(settings.text("settings_title"))
                    Button(action: retry) {
                        if isRefreshing { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel(settings.text("weather_refresh"))
                }
            }
            .task(id: settings.apiLanguageCode) { await refresh() }
            .refreshable { await refresh() }
            .refreshWeatherOnActivation { await refresh() }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingView() }
                .presentationDragIndicator(.visible)
        }
    }

    private func retry() {
        Task { await refresh() }
    }

    private func refresh() async {
        async let weather: Void = viewModel.refresh(lang: settings.apiLanguageCode)
        async let solar: Void = solarTimes.refresh(lang: settings.apiLanguageCode)
        _ = await (weather, solar)
    }

    private var isRefreshing: Bool { viewModel.isLoading || solarTimes.section.isLoading }
}

#Preview {
    HomeView()
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .environmentObject(AppSettings.preview)
}
