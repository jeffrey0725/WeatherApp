import SwiftUI
import Charts

struct HourlyRainfallView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = HourlyRainfallViewModel()
    @State private var query = ""
    @State private var showsMap = false
    @State private var selectedStation: RainfallStationSelection?
    @ScaledMetric private var chartRowHeight = 48.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WeatherDashboardSectionView(title: "rainfall_observations", section: viewModel.section,
                                            isRefreshing: viewModel.section.isLoading, retry: retry) { report in
                    Text(settings.text("rainfall_period")).font(.subheadline.bold())
                    Text("\(settings.timestamp(report.observationPeriod.start)) – \(settings.timestamp(report.observationPeriod.end))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(settings.text("rainfall_period_help")).font(.caption).foregroundStyle(.secondary)
                    rainfall(report)
                }
                Text(settings.text("weather_data_source")).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.text("rainfall_title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: settings.text("favorites_search"))
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: retry) {
                    if viewModel.section.isLoading { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(viewModel.section.isLoading)
                .accessibilityLabel(settings.text("weather_refresh"))
            }
        }
        .task(id: settings.apiLanguageCode) { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
        .onChange(of: settings.apiLanguageCode) { _, _ in selectedStation = nil }
        .sheet(item: $selectedStation) { selection in
            RainfallStationSheet(selection: selection,
                                 isPrevious: selection.isPrevious(currentCheck: viewModel.section.lastChecked,
                                                                  isLoading: viewModel.section.isLoading,
                                                                  hasError: viewModel.section.errorMessage != nil))
        }
    }

    @ViewBuilder
    private func rainfall(_ report: HourlyRainfallReport) -> some View {
        let results = RainfallMapResults(report: report, query: query)
        let ranked = results.ranked
        if report.readings.isEmpty {
            ContentUnavailableView(settings.text("rainfall_empty"), systemImage: "cloud.rain")
        } else {
            Picker(settings.text("explorer_display_mode"), selection: $showsMap) {
                Text(settings.text("explorer_list")).tag(false)
                Text(settings.text("explorer_map")).tag(true)
            }
            .pickerStyle(.segmented)

            // Keep the map mounted across display/filter changes; the page owns
            // selection so an empty result cannot dismiss an open station sheet.
            RainfallMapView(stations: results.stations, onSelect: { select($0, in: report) })
                .overlay {
                    if results.stations.isEmpty && showsMap {
                        ContentUnavailableView(settings.text(ranked.isEmpty ? "explorer_no_matches" : "rainfall_no_locations"),
                                               systemImage: "mappin.slash")
                    }
                }
                .frame(height: showsMap ? 440 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .opacity(showsMap ? 1 : 0)
                .allowsHitTesting(showsMap)
                .accessibilityHidden(!showsMap)
            if showsMap {
                Text(settings.text("rainfall_map_help")).font(.caption).foregroundStyle(.secondary)
                Text(settings.text("rainfall_map_legend")).font(.caption).foregroundStyle(.secondary)
                if !results.unmapped.isEmpty {
                    Text("\(settings.text("rainfall_unmapped_count")): \(results.unmapped.count)")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(settings.text("rainfall_show_list")) { showsMap = false }
                        .frame(minHeight: 44)
                }
            }
            if ranked.isEmpty {
                if !showsMap {
                    ContentUnavailableView {
                        Label(settings.text("explorer_no_matches"), systemImage: "magnifyingglass")
                    } description: {
                        Text(settings.text("explorer_search_help"))
                    }
                }
                Button(settings.text("explorer_clear_search")) { query = "" }
                    .frame(minHeight: 44)
            } else {
                let measured = ranked.filter { $0.amount != nil }
                let wettest = Array(ranked.filter { ($0.amount ?? 0) > 0 }.prefix(5))
                Divider()
                Text("\(settings.text("rainfall_matching_stations")): \(ranked.count)").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .topLeading)],
                          alignment: .leading, spacing: 16) {
                    metric("rainfall_highest", value: settings.measurement(measured.first?.amount, unit: "mm"))
                    metric("rainfall_wet_count", value: String(measured.filter { ($0.amount ?? 0) > 0 }.count))
                    metric("rainfall_unavailable_count", value: String(ranked.count - measured.count))
                }

                if !showsMap {
                    if !wettest.isEmpty {
                        Text(settings.text("rainfall_chart_title")).font(.headline)
                        rainfallChart(wettest)
                    } else {
                        Text(settings.text(measured.isEmpty ? "rainfall_no_readings" : "rainfall_zero_readings"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text(settings.text("rainfall_ranking")).font(.headline)
                    Text(settings.text("rainfall_ranking_help")).font(.caption).foregroundStyle(.secondary)
                    rankedList(ranked, report: report)
                }
            }
        }
    }

    private func rankedList(_ readings: [HourlyRainfallReading], report: HourlyRainfallReport) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(readings.enumerated()), id: \.element.id) { index, reading in
                Button { select(reading, in: report) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        if reading.amount != nil {
                            Text(String(index + 1)).font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary).frame(minWidth: 24)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reading.name(lang: settings.apiLanguageCode)).font(.subheadline.weight(.medium))
                            Text(reading.id).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(reading.displayText(settings: settings)).font(.subheadline.weight(.semibold))
                            .foregroundStyle(reading.amount == nil ? .secondary : .primary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityHint(settings.text("weather_read_details"))
                if index < readings.count - 1 { Divider() }
            }
        }
    }

    private func metric(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(settings.text(key)).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
        }
    }

    private func select(_ reading: HourlyRainfallReading, in report: HourlyRainfallReport) {
        selectedStation = RainfallStationSelection(reading: reading, report: report,
                                                   lastChecked: viewModel.section.lastChecked,
                                                   wasUnconfirmed: viewModel.section.isLoading || viewModel.section.errorMessage != nil)
    }

    private func rainfallChart(_ readings: [HourlyRainfallReading]) -> some View {
        Chart(readings) { reading in
            if let amount = reading.amount {
                BarMark(x: .value(settings.text("rainfall_amount"), amount),
                        y: .value(settings.text("favorites_station"), reading.id))
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .trailing) {
                        Text(settings.measurement(amount, unit: "mm")).font(.caption)
                    }
                    .accessibilityLabel(reading.name(lang: settings.apiLanguageCode))
                    .accessibilityValue(settings.measurement(amount, unit: "mm"))
            }
        }
        .chartYScale(domain: readings.map(\.id))
        .chartXScale(domain: 0...max(1, Double(readings.first?.amount ?? 0) * 1.25))
        .chartXAxisLabel("mm")
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let reading = readings.first(where: { $0.id == id }) {
                        Text(reading.name(lang: settings.apiLanguageCode)).font(.caption).lineLimit(2)
                    }
                }
            }
        }
        .frame(height: chartRowHeight * Double(readings.count) + 40)
    }

    private func retry() { Task { await refresh() } }
    private func refresh() async { await viewModel.refresh(lang: settings.apiLanguageCode) }
}

#Preview {
    NavigationStack { HourlyRainfallView() }.environmentObject(AppSettings.preview)
}
