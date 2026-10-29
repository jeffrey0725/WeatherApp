import SwiftUI

struct WeatherDashboardSectionView<Value, Content: View>: View {
    @EnvironmentObject private var settings: AppSettings
    let title: String
    let section: WeatherDashboardSection<Value>
    let isRefreshing: Bool
    let retry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.text(title)).font(.headline)
            if section.isLoading && section.value == nil {
                ProgressView(settings.text("weather_loading")).font(.subheadline)
            }
            if let error = section.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle").font(.subheadline)
                    Button(settings.text("weather_retry"), action: retry)
                        .disabled(isRefreshing)
                }
            }
            if let value = section.value {
                if section.errorMessage != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.text("weather_previous_data"))
                        if let checked = section.lastChecked {
                            Text("\(settings.text("weather_last_checked")): \(settings.timestamp(checked))")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                content(value)
            } else if !section.isLoading && section.errorMessage == nil {
                Text(settings.text("weather_unavailable")).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct DashboardConditionsView: View {
    @EnvironmentObject private var settings: AppSettings
    let report: RegionWeatherForecast
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = 56
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    temperature
                    icons
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    temperature
                    Spacer(minLength: 0)
                    icons.frame(maxWidth: 120)
                }
            }

            Divider()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .topLeading)],
                      alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(settings.text("weather_humidity"), systemImage: "humidity")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(settings.measurement(report.observatoryHumidity?.value,
                                                       unit: report.observatoryHumidity?.unit)).font(.title2.bold())
                    Text(settings.text("weather_observatory")).font(.caption).foregroundStyle(.secondary)
                    observationTime(report.humidity?.recordTime)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label(settings.text("weather_uv_index"), systemImage: "sun.max")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let reading = report.uvindex?.data?.first {
                        Text(reading.value.map { $0.formatted(.number.precision(.fractionLength(0...1)).locale(settings.locale)) }
                             ?? settings.text("weather_unavailable")).font(.title2.bold())
                        if let description = reading.desc, !description.isEmpty { Text(description).font(.subheadline) }
                        if let place = reading.place, !place.isEmpty { Text(place).font(.caption).foregroundStyle(.secondary) }
                    } else {
                        Text(settings.text("weather_unavailable")).font(.subheadline)
                    }
                    if let period = report.uvindex?.recordDesc, !period.isEmpty {
                        Text(period).font(.caption).foregroundStyle(.secondary)
                    }
                    if let message = report.uvindex?.message, !message.isEmpty {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            WeatherUpdateView(timestamp: report.updateTime)
        }
    }

    private var temperature: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(settings.text("weather_observatory")).font(.subheadline).foregroundStyle(.secondary)
            Text(settings.measurement(report.observatoryTemperature?.value,
                                               unit: report.observatoryTemperature?.unit))
                .font(report.observatoryTemperature?.value == nil ? .title2 :
                        .system(size: temperatureSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.blue)
                .fixedSize(horizontal: false, vertical: true)
            observationTime(report.temperature?.recordTime)
        }
    }

    @ViewBuilder
    private var icons: some View {
        if let icons = report.icon, !icons.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in WeatherIconView(icon: icon) }
            }
        }
    }

    @ViewBuilder
    private func observationTime(_ timestamp: String?) -> some View {
        if let time = settings.timestamp(timestamp) {
            Text("\(settings.text("weather_observed_at")): \(time)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DashboardWarningsView: View {
    @EnvironmentObject private var settings: AppSettings
    let report: WeatherWarningReport
    let lastChecked: Date?
    let isPrevious: Bool
    var showsAllWarningsLink = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                let snapshot = WeatherWarningSnapshot(report: report, lastChecked: lastChecked,
                                                      isRefreshing: isPrevious, hasError: false)
                if let lastChecked, !isPrevious {
                    Text("\(settings.text("weather_last_checked")): \(settings.timestamp(lastChecked))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if snapshot.state != .current {
                    Text(settings.text("weather_warning_status_unknown"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if snapshot.state != .unavailable {
                    Text(settings.text(snapshot.state == .previous ? "weather_previous_warnings" : "weather_active_warnings"))
                        .font(.subheadline.bold())
                }
                let keys = snapshot.activeWarningKeys(at: context.date)
                if keys.isEmpty && snapshot.state != .unavailable {
                    Text(settings.text(snapshot.emptyMessageKey))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(keys, id: \.self) { key in
                    if let warning = report.summary[key] {
                        NavigationLink {
                            WeatherWarningDetailView(title: warning.name ?? key,
                                                     text: report.details(for: key, warning: warning, noDetailsText: settings.text("weather_warning_no_details")),
                                                     timestamp: warning.updateTime, isPrevious: isPrevious)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(warning.name ?? key, systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline).foregroundStyle(.orange)
                                Text(warning.type ?? warning.code ?? key).foregroundStyle(.primary)
                                WeatherUpdateView(timestamp: warning.updateTime)
                                if let expiry = settings.timestamp(warning.expireTime) {
                                    Text("\(settings.text("weather_expires")): \(expiry)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text(settings.text("weather_read_details")).font(.caption).foregroundStyle(.blue)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(Array((report.information.details ?? []).enumerated()), id: \.offset) { _, detail in
                    if detail.warningStatementCode == "WTCPRE8" {
                        announcement(title: "weather_pre8_announcement",
                                     text: (detail.contents ?? []).joined(separator: "\n\n"), timestamp: detail.updateTime)
                    }
                }
                ForEach(Array((report.tips.swt ?? []).enumerated()), id: \.offset) { _, tip in
                    if let text = tip.desc, !text.isEmpty {
                        announcement(title: "weather_special_tips", text: text, timestamp: tip.updateTime)
                    }
                }
                if showsAllWarningsLink {
                    NavigationLink(settings.text("weather_all_warnings")) { WeatherWarningsView() }.font(.subheadline)
                }
            }
        }
    }

    private func announcement(title: String, text: String, timestamp: String?) -> some View {
        NavigationLink {
            WeatherWarningDetailView(title: settings.text(title), text: text, timestamp: timestamp, isPrevious: isPrevious)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(settings.text(title)).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(text).font(.subheadline).lineLimit(2).foregroundStyle(.primary)
                WeatherUpdateView(timestamp: timestamp)
                Text(settings.text("weather_read_details")).font(.caption).foregroundStyle(.blue)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardLocalForecastView: View {
    @EnvironmentObject private var settings: AppSettings
    let forecast: LocalWeatherForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeatherUpdateView(timestamp: forecast.updateTime)
            if let period = forecast.forecastPeriod, !period.isEmpty { Text(period).font(.subheadline.bold()) }
            Text(forecast.forecastDesc.flatMap { $0.isEmpty ? nil : $0 } ?? settings.text("weather_unavailable"))
            if let outlook = forecast.outlook, !outlook.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text("weather_outlook")).font(.subheadline.bold())
                    Text(outlook).font(.subheadline)
                }
            }
            NavigationLink(settings.text("weather_full_local_forecast")) { LocalWeatherInfoView() }.font(.subheadline)
        }
    }
}

struct DashboardForecastPreviewView: View {
    @EnvironmentObject private var settings: AppSettings
    let forecast: NineDayWeatherForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeatherUpdateView(timestamp: forecast.updateTime)
            if forecast.preview.isEmpty { Text(settings.text("weather_unavailable")).foregroundStyle(.secondary) }
            ForEach(Array(forecast.preview.enumerated()), id: \.offset) { index, day in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.forecastDate(day.forecastDate)).font(.subheadline.bold())
                            if let week = day.week, !week.isEmpty { Text(week).font(.caption).foregroundStyle(.secondary) }
                            Text(settings.range(min: day.forecastMintemp?.value,
                                                         max: day.forecastMaxtemp?.value,
                                                         unit: day.forecastMintemp?.unit ?? day.forecastMaxtemp?.unit))
                                .font(.title3)
                                .accessibilityLabel("\(settings.text("weather_low")): \(settings.measurement(day.forecastMintemp?.value, unit: day.forecastMintemp?.unit)); \(settings.text("weather_high")): \(settings.measurement(day.forecastMaxtemp?.value, unit: day.forecastMaxtemp?.unit))")
                        }
                        Spacer(minLength: 0)
                        if let icon = day.ForecastIcon { WeatherIconView(icon: icon) }
                    }
                    if let description = day.forecastWeather, !description.isEmpty { Text(description).font(.subheadline) }
                    if let rain = day.PSR, !rain.isEmpty {
                        Text("\(settings.text("weather_significant_rain")): \(rain)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink(settings.text("weather_full_nine_day")) { NineDayWeatherInfoView() }.font(.subheadline)
        }
    }
}
