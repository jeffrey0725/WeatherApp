//
//  RegionMapView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 29/8/2025.
//

import SwiftUI
import MapKit
import SwiftData

struct RegionMapView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedStation: RegionalStationSelection?
    @State private var position: MapCameraPosition = .region(RegionMapView.initialRegion)
    let stations: [TemperatureData]
    let observationTime: String?
    let selectionID: String?
    let onSelect: ((RegionalStationSelection) -> Void)?

    init(stations: [TemperatureData], observationTime: String? = nil,
         selectionID: String? = nil, onSelect: ((RegionalStationSelection) -> Void)? = nil) {
        self.stations = stations
        self.observationTime = observationTime
        self.selectionID = selectionID
        self.onSelect = onSelect
    }

    private var annotations: [RegionalStationSelection] {
        stations.compactMap { station in
            guard station.place != nil, station.value != nil,
                  station.latitude != nil, station.longitude != nil else { return nil }
            let catalog = StationCoordinateStore.stationCoordinates.first {
                $0.placeEN == station.place || $0.placeTC == station.place
            }
            return RegionalStationSelection(id: catalog?.id ?? station.id.uuidString, station: station,
                                    observationTime: observationTime)
        }
    }

    private static let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            latitudinalMeters: 50000,
            longitudinalMeters: 50000
        )
    
    var body: some View {
        Map(position: $position) {
            ForEach(annotations) { annotation in
                let station = annotation.station
                if let _place = station.place, let _latitude = station.latitude, let _longitude = station.longitude, station.value != nil {
                    Annotation(_place, coordinate: CLLocationCoordinate2D(latitude: _latitude, longitude: _longitude)) {
                        Button {
                            // Keep the reading and its observation time from the same report.
                            if let onSelect { onSelect(annotation) }
                            else { selectedStation = annotation }
                        } label: {
                            VStack(spacing: 0) {
                                Text(settings.measurement(station.value, unit: station.unit))
                                    .font(.callout.weight(.semibold)).monospacedDigit()
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .foregroundStyle(.white)
                                    .background((selectionID ?? selectedStation?.id) == annotation.id ? Color.indigo : Color.blue,
                                                in: Capsule())
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle((selectionID ?? selectedStation?.id) == annotation.id ? Color.indigo : Color.blue)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(_place), \(settings.measurement(station.value, unit: station.unit))")
                        .accessibilityHint(settings.text("weather_read_details"))
                    }
                }
            }
        }
        .frame(height: 500)
        .onChange(of: annotations.map(\.id)) { _, identifiers in
            position = identifiers.isEmpty ? .region(Self.initialRegion) : .automatic
        }
        
        // Bottom sheet
        .sheet(item: $selectedStation) { selection in
            RegionalWeatherBottomSheetView(station: selection.station, observationTime: selection.observationTime)
        }
    }
}

#Preview {
    RegionMapView(stations: [])
        .modelContainer(for: FavoriteStation.self, inMemory: true)
        .environmentObject(AppSettings.preview)
}
