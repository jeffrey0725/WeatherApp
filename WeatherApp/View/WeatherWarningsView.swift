import SwiftUI

struct WeatherWarningsView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var weatherViewModel = WeatherViewModel()

    private var section: WeatherDashboardSection<WeatherWarningReport> {
        WeatherDashboardSection(value: weatherViewModel.lastChecked == nil ? nil : weatherViewModel.warningReport,
                                isLoading: weatherViewModel.isLoading, errorMessage: weatherViewModel.errorMessage,
                                lastChecked: weatherViewModel.lastChecked)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeatherDashboardSectionView(title: "weather_warnings_title", section: section,
                                            isRefreshing: weatherViewModel.isLoading, retry: retry) { report in
                    DashboardWarningsView(report: report, lastChecked: weatherViewModel.lastChecked,
                                          isPrevious: weatherViewModel.isLoading || weatherViewModel.errorMessage != nil,
                                          showsAllWarningsLink: false)
                }
                if weatherViewModel.lastChecked == nil && !weatherViewModel.isLoading {
                    Text(settings.text("weather_warning_status_unknown"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(settings.text("weather_warnings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
    }

    private func retry() { Task { await refresh() } }
    private func refresh() async { await weatherViewModel.loadWarnings(lang: settings.apiLanguageCode) }
}

struct WeatherWarningDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let text: String
    let timestamp: String?
    var isPrevious = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isPrevious {
                    Text(settings.text("weather_previous_data")).font(.headline)
                    Text(settings.text("weather_warning_status_unknown"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                WeatherUpdateView(timestamp: timestamp)
                Text(text).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WeatherWarningsView()
        .environmentObject(AppSettings.preview)
}
