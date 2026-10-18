//
//  RegionalWeatherBottomSheetView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 6/4/2026.
//

import SwiftUI
import SwiftData

struct RegionalWeatherBottomSheetView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var favorites: [FavoriteStation]
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = 68
    @State private var saveFailed = false

    let station: TemperatureData
    let observationTime: String?

    init(station: TemperatureData, observationTime: String? = nil) {
        self.station = station
        self.observationTime = observationTime
    }

    private var catalogStation: StationCoordinate? {
        StationCoordinateStore.stationCoordinates.first { $0.placeEN == station.place || $0.placeTC == station.place }
    }

    private var isFavorite: Bool {
        guard let catalogStation else { return false }
        return favorites.contains { $0.stationID == catalogStation.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                temperatureCard
                if let catalogStation {
                    Button {
                        toggleFavorite(catalogStation)
                    } label: {
                        Label(settings.text(isFavorite ? "favorites_remove_station" : "favorites_save_station"),
                              systemImage: isFavorite ? "star.fill" : "star")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                }
                Text(settings.text("weather_data_source"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(460), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color(.systemBackground))
        .presentationContentInteraction(.resizes)
        .alert(settings.text("favorites_save_error_title"), isPresented: $saveFailed) {
            Button(settings.text("weather_close"), role: .cancel) {}
        } message: {
            Text(settings.text("favorites_save_error_message"))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.text("favorites_station"))
                    .font(.caption).foregroundStyle(.secondary)
                Text(station.place ?? settings.text("weather_unavailable"))
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(settings.text("weather_close"))
        }
    }

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.text("station_temperature"))
                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            Text(settings.measurement(station.value, unit: station.unit))
                .font(station.value == nil ? .title2 :
                        .system(size: temperatureSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Divider().overlay(Color.blue.opacity(0.08))
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "clock").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text("weather_observed_at")).font(.caption)
                    Text(settings.timestamp(observationTime) ?? settings.text("weather_unavailable"))
                        .font(.subheadline.weight(.medium))
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.13), Color.cyan.opacity(0.06)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .accessibilityElement(children: .combine)
    }

    private func toggleFavorite(_ station: StationCoordinate) {
        let store = FavoriteStationStore(context: context)
        do {
            if isFavorite { try store.remove(stationIDs: [station.id]) }
            else { try store.add(stationID: station.id) }
        } catch {
            saveFailed = true
        }
    }
}

#Preview("Station sheet") {
    RegionalWeatherBottomSheetView(
        station: TemperatureData(place: "Sha Tin", unit: "C", value: 27),
        observationTime: "2026-10-13T18:00:00+08:00")
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .environmentObject(AppSettings.preview)
}

#Preview("Unavailable observation") {
    RegionalWeatherBottomSheetView(station: TemperatureData(place: "Sha Tin", unit: "C"))
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .preferredColorScheme(.dark)
        .environmentObject(AppSettings.preview)
}
