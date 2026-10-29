import SwiftUI
import MapKit

struct RainfallMapView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var position: MapCameraPosition = .automatic
    @State private var latitudeSpan = 0.35
    var isCompact: Bool { RainfallMarkerStyle.isCompact(latitudeSpan: latitudeSpan) }
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
                                                              longitude: station.location.longitude),
                           anchor: isCompact ? .center : .bottom) {
                    Button { onSelect(station.reading) } label: {
                        marker(for: station.reading)
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
        .onMapCameraChange(frequency: .onEnd) { context in
            latitudeSpan = context.region.span.latitudeDelta
        }
        .onChange(of: stations.map(\.id).sorted(), initial: true) { _, ids in
            position = ids.isEmpty ? .region(Self.hongKong) : .automatic
        }
    }

    @ViewBuilder
    private func marker(for reading: HourlyRainfallReading) -> some View {
        if isCompact {
            Text(RainfallMarkerStyle.compactText(for: reading.status))
                .font(.caption.weight(.bold)).monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 4)
                .frame(minWidth: 26)
                .foregroundStyle(.white)
                .background(markerColor(reading), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
        } else {
            VStack(spacing: 0) {
                Text(markerText(reading))
                    .font(.callout.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(markerColor(reading), in: Capsule())
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 8)).foregroundStyle(markerColor(reading))
            }
        }
    }

    private func markerText(_ reading: HourlyRainfallReading) -> String {
        switch reading.status {
        case .measured(let amount): return settings.measurement(amount, unit: "mm")
        case .maintenance: return "M"
        case .unavailable: return "—"
        }
    }

    // Darker than the system colors so the white label reaches at least 4.5:1 contrast.
    private func markerColor(_ reading: HourlyRainfallReading) -> Color {
        switch reading.status {
        case .measured(let amount):
            return amount > 0 ? Color(red: 0.04, green: 0.38, blue: 0.85) : Color(red: 0.0, green: 0.46, blue: 0.49)
        case .maintenance: return Color(red: 0.78, green: 0.38, blue: 0.0)
        case .unavailable: return Color(white: 0.42)
        }
    }
}
