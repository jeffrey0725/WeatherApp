import SwiftUI

struct NineDayWeatherInfoView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var weatherViewModel = WeatherViewModel()

    private var forecast: NineDayWeatherForecast { weatherViewModel.nineDayWeatherForecast }
    private var section: WeatherDashboardSection<NineDayWeatherForecast> {
        WeatherDashboardSection(value: weatherViewModel.lastChecked == nil ? nil : forecast,
                                isLoading: weatherViewModel.isLoading,
                                errorMessage: weatherViewModel.errorMessage,
                                lastChecked: weatherViewModel.lastChecked)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                WeatherDashboardSectionView(title: "forecast_temperature_trend", section: section,
                                            isRefreshing: weatherViewModel.isLoading, retry: retry) { report in
                    WeatherUpdateView(timestamp: report.updateTime)
                    if (report.weatherForecast ?? []).isEmpty {
                        Text(settings.text("forecast_empty")).foregroundStyle(.secondary)
                    } else {
                        NineDayForecastChartView(forecast: report)
                        Divider()
                        Text(settings.text("forecast_all_days")).font(.headline)
                        ForEach(Array((report.weatherForecast ?? []).enumerated()), id: \.offset) { _, day in
                            DailyWeatherDetailView(weatherForecast: day)
                        }
                    }
                    if let situation = report.generalSituation, !situation.isEmpty {
                        Text(settings.text("general_situtation")).font(.headline)
                        Text(situation)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.text("nine_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: retry) { RefreshToolbarLabel(isLoading: weatherViewModel.isLoading) }
                    .disabled(weatherViewModel.isLoading)
            }
            .keepVisibleLongest()
        }
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
    }

    private func retry() { Task { await refresh() } }

    private func refresh() async {
        await weatherViewModel.loadNineDayForecast(lang: settings.apiLanguageCode)
    }
}

#Preview {
    NineDayWeatherInfoView()
        .environmentObject(AppSettings.preview)
}
