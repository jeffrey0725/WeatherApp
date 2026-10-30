import SwiftUI

struct MoonTidesView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = MoonTidesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    TwoColumnWhenWide {
                        WeatherDashboardSectionView(title: "moon_title", section: viewModel.moon,
                                                    isRefreshing: viewModel.isLoading, retry: retry) { snapshot in
                            MoonTimesCardContent(snapshot: snapshot, now: context.date)
                        }
                    } trailing: {
                        stationPicker
                        WeatherDashboardSectionView(title: "tide_title", section: viewModel.tides,
                                                    isRefreshing: viewModel.isLoading, retry: retry) { snapshot in
                            TideTimesCardContent(snapshot: snapshot, now: context.date)
                        }
                    }
                    // A visible screen also needs a fresh request at Hong Kong midnight.
                    .onChange(of: SolarDay.calendar.startOfDay(for: context.date)) { _, _ in retry() }
                }
                Text(settings.text("weather_data_source")).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: AdaptiveLayout.dashboardMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.text("moon_tides_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: retry) { RefreshToolbarLabel(isLoading: viewModel.isLoading) }
                    .disabled(viewModel.isLoading)
            }
            .keepVisibleLongest()
        }
        .task(id: "\(settings.apiLanguageCode)|\(settings.tideStationID)") { await refresh() }
        .refreshable { await refresh() }
        .refreshWeatherOnActivation { await refresh() }
    }

    // Always visible, so another station can be chosen while the current one is loading or has failed.
    private var stationPicker: some View {
        HStack {
            Text(settings.text("tide_station")).font(.headline)
            Spacer(minLength: 8)
            Picker(settings.text("tide_station"), selection: $settings.tideStationID) {
                ForEach(TideStationCatalog.sortedStations(lang: settings.apiLanguageCode)) { station in
                    Text(station.name(lang: settings.apiLanguageCode)).tag(station.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minHeight: 44)
            .accessibilityLabel(settings.text("tide_station"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private func retry() { Task { await refresh() } }
    private func refresh() async {
        await viewModel.refresh(lang: settings.apiLanguageCode, station: settings.tideStation)
    }
}

#Preview {
    NavigationStack { MoonTidesView() }.environmentObject(AppSettings.preview)
}
