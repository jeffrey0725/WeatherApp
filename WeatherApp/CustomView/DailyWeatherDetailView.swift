import SwiftUI

struct DailyWeatherDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    let weatherForecast: WeatherForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(settings.forecastDate(weatherForecast.forecastDate)) \(weatherForecast.week ?? "")")
                    .font(.headline)
                Spacer()
                if let icon = weatherForecast.ForecastIcon {
                    WeatherIconView(icon: icon)
                }
            }
            if let description = weatherForecast.forecastWeather, !description.isEmpty {
                Text(description)
            }
            HStack(alignment: .top) {
                metric("weather_low", value: settings.measurement(
                    weatherForecast.forecastMintemp?.value, unit: weatherForecast.forecastMintemp?.unit))
                Spacer()
                metric("weather_high", value: settings.measurement(
                    weatherForecast.forecastMaxtemp?.value, unit: weatherForecast.forecastMaxtemp?.unit))
            }
            if weatherForecast.forecastMinrh?.value != nil || weatherForecast.forecastMaxrh?.value != nil {
                Text("\(settings.text("weather_humidity")): \(settings.range(min: weatherForecast.forecastMinrh?.value, max: weatherForecast.forecastMaxrh?.value, unit: "%"))")
            }
            if let wind = weatherForecast.forecastWind, !wind.isEmpty {
                Text("\(settings.text("weather_wind")): \(wind)")
            }
            if let rain = weatherForecast.PSR, !rain.isEmpty {
                // PSR is HKO's qualitative category, not a percentage.
                Text("\(settings.text("weather_significant_rain")): \(rain)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupedCardInset, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settings.text(title)).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2)
        }
    }
}

#Preview {
    DailyWeatherDetailView(weatherForecast: WeatherForecast())
        .environmentObject(AppSettings.preview)
}
