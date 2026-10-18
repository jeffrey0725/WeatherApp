import SwiftUI
import MapKit

struct RainfallMapView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var position: MapCameraPosition = .automatic
    let stations: [RainfallMapStation]
    let onSelect: (HourlyRainfallReading) -> Void

    private static let hongKong = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.35, longitude: 114.13),
        latitudinalMeters: 52000, longitudinalMeters: 52000)

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(stations) { station in
                Annotation(station.reading.name(lang: settings.apiLanguageCode),
                           coordinate: CLLocationCoordinate2D(latitude: station.location.latitude,
                                                              longitude: station.location.longitude)) {
                    Button { onSelect(station.reading) } label: {
                        VStack(spacing: 0) {
                            Text(markerText(station.reading))
                                .font(.callout.weight(.semibold)).monospacedDigit()
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .foregroundStyle(.white)
                                .background(markerColor(station.reading), in: Capsule())
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8)).foregroundStyle(markerColor(station.reading))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(station.reading.name(lang: settings.apiLanguageCode))
                    .accessibilityValue(station.reading.displayText(settings: settings))
                    .accessibilityHint(settings.text("weather_read_details"))
                }
            }
        }
        .mapControls { MapCompass() }
        .onChange(of: stations.map(\.id).sorted(), initial: true) { _, ids in
            position = ids.isEmpty ? .region(Self.hongKong) : .automatic
        }
    }

    private func markerText(_ reading: HourlyRainfallReading) -> String {
        switch reading.status {
        case .measured(let amount): return settings.measurement(amount, unit: "mm")
        case .maintenance: return "M"
        case .unavailable: return "—"
        }
    }

    private func markerColor(_ reading: HourlyRainfallReading) -> Color {
        switch reading.status {
        case .measured(let amount): return amount > 0 ? .blue : .teal
        case .maintenance: return .orange
        case .unavailable: return .gray
        }
    }
}
