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
                TwoColumnWhenWide {
                    header
                    WeatherDashboardSectionView(title: "weather_conditions", section: viewModel.current, isRefreshing: viewModel.isLoading, retry: retry) { report in
                        DashboardConditionsView(report: report)
                    }
                    WeatherDashboardSectionView(title: "weather_warnings_title", section: viewModel.warnings, isRefreshing: viewModel.isLoading, retry: retry) { report in
                        DashboardWarningsView(report: report, lastChecked: viewModel.warnings.lastChecked,
                                              isPrevious: viewModel.warnings.errorMessage != nil, retry: retry)
                    }
                    DashboardFavoriteStationsView(section: viewModel.current, isRefreshing: viewModel.isLoading, retry: retry)
                    shortcut(icon: "map.fill", title: "weather_regional_shortcut", subtitle: "weather_regional_description") {
                        RegionalWeatherExplorerView()
                    }
                    shortcut(icon: "cloud.rain.fill", title: "rainfall_title", subtitle: "rainfall_shortcut_description") {
                        HourlyRainfallView()
                    }
                    shortcut(icon: "moon.stars.fill", title: "moon_tides_title", subtitle: "moon_tides_shortcut_description") {
                        MoonTidesView()
                    }
                } trailing: {
                    DashboardSolarTimesView(viewModel: solarTimes, isRefreshing: isRefreshing, retry: retry)
                    WeatherDashboardSectionView(title: "local_weather_title", section: viewModel.local, isRefreshing: viewModel.isLoading, retry: retry) { forecast in
                        DashboardLocalForecastView(forecast: forecast)
                    }
                    WeatherDashboardSectionView(title: "weather_next_three_days", section: viewModel.forecast, isRefreshing: viewModel.isLoading, retry: retry) { forecast in
                        DashboardForecastPreviewView(forecast: forecast)
                    }
                    browseReports
                }
                .padding()
                .frame(maxWidth: AdaptiveLayout.dashboardMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.text("weather_today"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Label(settings.text("settings_title"), systemImage: "gearshape")
                    }
                    Button(action: retry) { RefreshToolbarLabel(isLoading: isRefreshing) }
                        .disabled(isRefreshing)
                }
                .keepVisibleLongest()
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


    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settings.text("weather_hong_kong")).font(.title2.bold())
            Text(settings.text("weather_data_source"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func shortcut<Destination: View>(icon: String, title: String, subtitle: String,
                                             @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(title)).font(.headline)
                    Text(settings.text(subtitle)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // Detail screens remain accessible even if a dashboard request fails.
    private var browseReports: some View {
        NavigationLink(settings.text("weather_browse_reports")) {
            List {
                NavigationLink(settings.text("favorites_title")) { FavoriteStationsView() }
                NavigationLink(settings.text("local_weather_title")) { LocalWeatherInfoView() }
                NavigationLink(settings.text("nine_weather_title")) { NineDayWeatherInfoView() }
                NavigationLink(settings.text("region_weather_title")) { RegionWeatherInfoView() }
                NavigationLink(settings.text("rainfall_title")) { HourlyRainfallView() }
                NavigationLink(settings.text("moon_tides_title")) { MoonTidesView() }
                NavigationLink(settings.text("weather_warnings_title")) { WeatherWarningsView() }
            }
            .navigationTitle(settings.text("weather_browse_reports"))
        }
        .font(.subheadline)
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
