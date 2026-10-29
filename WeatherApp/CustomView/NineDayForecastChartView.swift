import SwiftUI
import Charts

struct NineDayForecastChartView: View {
    @EnvironmentObject private var settings: AppSettings
    let forecast: NineDayWeatherForecast
    @State private var selectedDayID: String?
    @ScaledMetric private var chartHeight = 260.0

    private var data: NineDayForecastChartData { NineDayForecastChartData(forecast: forecast) }

    var body: some View {
        let data = self.data
        let points = data.points(unit: settings.temperatureUnit)
        let selected = data.selectedDay(id: selectedDayID)
        VStack(alignment: .leading, spacing: 16) {
            if points.isEmpty {
                Text(settings.text("forecast_chart_no_temperatures"))
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(settings.text("forecast_chart_help"))
                    .font(.caption).foregroundStyle(.secondary)
                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        temperatureChart(data, points: points, selected: selected)
                            .frame(width: max(geometry.size.width, CGFloat(data.days.count) * 48 + 44),
                                   height: chartHeight)
                    }
                }
                .frame(height: chartHeight + 12)
            }
            if data.hasUnavailableValues {
                Text(settings.text("forecast_chart_partial"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !data.days.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(data.days) { day in
                            Button { selectedDayID = day.id } label: {
                                VStack(spacing: 4) {
                                    Text(axisDate(day.date)).font(.subheadline.bold())
                                    Text(settings.range(min: day.lowCelsius, max: day.highCelsius, unit: "C"))
                                        .font(.caption)
                                }
                                .padding(10)
                                .frame(minWidth: 64, minHeight: 44)
                                .background(selected?.id == day.id ? Color.accentColor.opacity(0.15) : Color.groupedCardInset,
                                            in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(settings.forecastDate(day.id))
                            .accessibilityValue(settings.range(min: day.lowCelsius, max: day.highCelsius, unit: "C"))
                            .accessibilityHint(settings.text("forecast_select_day"))
                            .accessibilityAddTraits(selected?.id == day.id ? .isSelected : [])
                        }
                    }
                }
                if let selected {
                    Text(settings.text("forecast_selected_day")).font(.subheadline.bold())
                    DailyWeatherDetailView(weatherForecast: selected.forecast)
                }
            }
        }
        .onChange(of: data.days.map(\.id), initial: true) { _, _ in
            selectedDayID = data.selectedDay(id: selectedDayID)?.id
        }
    }

    private func temperatureChart(_ data: NineDayForecastChartData, points: [NineDayForecastChartData.Point],
                                  selected: NineDayForecastChartData.Day?) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value(settings.text("forecast_day"), point.date),
                         y: .value(settings.temperatureUnit.symbol, point.value),
                         series: .value("segment", point.seriesID))
                    .foregroundStyle(by: .value(settings.text("forecast_temperature"), settings.text(point.kind.titleKey)))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: point.kind == .low ? [5, 3] : []))
                    .interpolationMethod(.linear)
                    .accessibilityHidden(true)
                PointMark(x: .value(settings.text("forecast_day"), point.date),
                          y: .value(settings.temperatureUnit.symbol, point.value))
                    .foregroundStyle(by: .value(settings.text("forecast_temperature"), settings.text(point.kind.titleKey)))
                    .symbol(point.kind == .low ? .square : .circle)
                    .symbolSize(point.dayID == selected?.id ? 70 : 35)
                    .accessibilityLabel("\(settings.forecastDate(point.dayID)), \(settings.text(point.kind.titleKey))")
                    .accessibilityValue(settings.measurement(point.celsius, unit: "C"))
            }
            if let selected {
                RuleMark(x: .value(settings.text("forecast_day"), selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .accessibilityHidden(true)
            }
        }
        .chartForegroundStyleScale(domain: [settings.text("weather_low"), settings.text("weather_high")],
                                   range: [Color.blue, Color.orange])
        .chartLegend(position: .bottom)
        .chartXScale(domain: xDomain(data))
        .chartYScale(domain: yDomain(points))
        .chartXAxisLabel(settings.text("forecast_hong_kong_dates"))
        .chartYAxisLabel(settings.temperatureUnit.symbol)
        .chartXAxis {
            AxisMarks(values: data.days.map(\.date)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) { Text(axisDate(date)).font(.caption) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        guard let anchor = proxy.plotFrame else { return }
                        let frame = geometry[anchor]
                        guard frame.contains(tap.location),
                              let date = proxy.value(atX: tap.location.x - frame.minX, as: Date.self) else { return }
                        selectedDayID = data.nearestDay(to: date)?.id
                    })
                    .accessibilityHidden(true)
            }
        }
    }

    private func axisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = settings.locale
        formatter.calendar = NineDayForecastChartData.calendar
        formatter.timeZone = NineDayForecastChartData.calendar.timeZone
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }

    private func xDomain(_ data: NineDayForecastChartData) -> ClosedRange<Date> {
        let first = data.days.first?.date ?? .now
        let last = data.days.last?.date ?? first
        return first.addingTimeInterval(-43200)...last.addingTimeInterval(43200)
    }

    private func yDomain(_ points: [NineDayForecastChartData.Point]) -> ClosedRange<Double> {
        let low = points.map(\.value).min() ?? 0
        let high = points.map(\.value).max() ?? low
        let padding = max(2, (high - low) * 0.15)
        return (low - padding)...(high + padding)
    }
}
