import SwiftUI

struct LocalWeatherInfoView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var weatherViewModel = WeatherViewModel()

    private var forecast: LocalWeatherForecast { weatherViewModel.localWeatherForecast }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeatherStatusView(viewModel: weatherViewModel) {
                    Task { await refresh() }
                }
                WeatherUpdateView(timestamp: forecast.updateTime)
                if let period = forecast.forecastPeriod, !period.isEmpty {
                    Text(period).font(.headline)
                }
                section("general_situtation", text: forecast.generalSituation)
                section("weather_forecast", text: forecast.forecastDesc)
                section("weather_cyclone_info", text: forecast.tcInfo)
                section("weather_fire_warning", text: forecast.fireDangerWarning)
                section("weather_outlook", text: forecast.outlook)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(settings.text("local_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
    }

    @ViewBuilder
    private func section(_ title: String, text: String?) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.text(title)).font(.headline)
                Text(text)
            }
        }
    }

    private func refresh() async {
        await weatherViewModel.loadLocalForecast(lang: settings.apiLanguageCode)
    }
}

#Preview {
    LocalWeatherInfoView()
        .environmentObject(AppSettings.preview)
}
