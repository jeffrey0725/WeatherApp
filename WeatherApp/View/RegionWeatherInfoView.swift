import SwiftUI
import SwiftData

struct RegionWeatherInfoView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var weatherViewModel = WeatherViewModel()

    private var report: RegionWeatherForecast { weatherViewModel.regionWeatherForecast }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeatherStatusView(viewModel: weatherViewModel) {
                    Task { await refresh() }
                }
                WeatherUpdateView(timestamp: report.updateTime)

                if let icons = report.icon, !icons.isEmpty {
                    HStack {
                        Text(settings.text("weather_conditions")).font(.headline)
                        Spacer()
                        ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                            WeatherIconView(icon: icon)
                        }
                    }
                }
                banners(report.specialWxTips ?? report.speicalWxTips)
                banners(report.tcmessage)
                banners(report.warningMessage)

                if let humidity = report.humidity, let readings = humidity.data, !readings.isEmpty {
                    Text(settings.text("weather_humidity")).font(.headline)
                    WeatherUpdateView(timestamp: humidity.recordTime)
                    ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                        Text("\(reading.place ?? ""): \(settings.measurement(reading.value, unit: reading.unit))")
                    }
                }

                Text(settings.text("weather_uv_index")).font(.headline)
                if let uv = report.uvindex, let readings = uv.data, !readings.isEmpty {
                    if let record = uv.recordDesc, !record.isEmpty {
                        Text(record).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                        Text("\(reading.place ?? ""): \(reading.value.map { $0.formatted(.number.precision(.fractionLength(0...1)).locale(settings.locale)) } ?? settings.text("weather_unavailable")) \(reading.desc ?? "")")
                    }
                    if let message = uv.message, !message.isEmpty { Text(message) }
                } else {
                    Text(report.uvindex?.message ?? settings.text("weather_unavailable"))
                        .foregroundStyle(.secondary)
                }

                if let rainfall = report.rainfall, let readings = rainfall.data, !readings.isEmpty {
                    Text(settings.text("region_weather_rainfall_title")).font(.headline)
                    if let start = settings.timestamp(rainfall.startTime),
                       let end = settings.timestamp(rainfall.endTime) {
                        Text("\(start) – \(end)").font(.caption).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(reading.place ?? "").font(.headline)
                                    if reading.main?.uppercased() == "TRUE" {
                                        Text(settings.text("weather_unavailable"))
                                    } else {
                                        Text("\(settings.text("region_weather_rainfall_max")): \(settings.measurement(reading.max, unit: reading.unit))")
                                        if let min = reading.min {
                                            Text("\(settings.text("region_weather_rainfall_min")): \(settings.measurement(min, unit: reading.unit))")
                                        }
                                    }
                                }
                                .padding()
                                .frame(width: 180, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                if let temperature = report.temperature, let stations = temperature.data, !stations.isEmpty {
                    Text(settings.text("region_weather_temperature_title")).font(.headline)
                    WeatherUpdateView(timestamp: temperature.recordTime)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(stations) { station in
                                RegionalWeatherDetailView(regionalWeatherDetail: RegionalWeatherDetail(
                                    topTitle: station.place,
                                    bottomTitle: settings.measurement(station.value, unit: station.unit)))
                            }
                        }
                    }
                    RegionMapView(stations: stations, observationTime: temperature.recordTime)
                        .frame(height: 500)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(settings.text("region_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
    }

    @ViewBuilder
    private func banners(_ messages: [String]?) -> some View {
        if let messages, !messages.isEmpty { RollingBannerView(content: messages) }
    }

    private func refresh() async {
        await weatherViewModel.loadCurrentReport(lang: settings.apiLanguageCode)
    }
}

#Preview {
    RegionWeatherInfoView()
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .environmentObject(AppSettings.preview)
}
