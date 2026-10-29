import SwiftUI

struct RegionalStationListView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stations: [RegionalStationObservation]
    let favoriteIDs: Set<String>
    let observationTime: String?
    let onSelect: (RegionalStationSelection) -> Void

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(stations) { observation in
                Button {
                    onSelect(observation.selection(lang: settings.apiLanguageCode, observationTime: observationTime))
                } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) {
                                stationName(observation)
                                temperature(observation)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                stationName(observation)
                                Spacer(minLength: 8)
                                temperature(observation)
                                Image(systemName: "chevron.right").font(.caption.bold())
                                    .foregroundStyle(.secondary).padding(.top, 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(16)
                    .background(Color.groupedCard, in: RoundedRectangle(cornerRadius: 16))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(observation))
                .accessibilityHint(settings.text("weather_read_details"))
            }
        }
    }

    private func stationName(_ observation: RegionalStationObservation) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(observation.station.name(lang: settings.apiLanguageCode))
                .font(.headline).fixedSize(horizontal: false, vertical: true)
            if favoriteIDs.contains(observation.id) {
                Image(systemName: "star.fill").font(.caption).foregroundStyle(.orange)
            }
        }
        .foregroundStyle(.primary)
    }

    private func temperature(_ observation: RegionalStationObservation) -> some View {
        Text(settings.measurement(observation.reading?.value, unit: observation.reading?.unit))
            .font(observation.reading?.value == nil ? .subheadline : .title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(observation.reading?.value == nil ? .secondary : .primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func accessibilityLabel(_ observation: RegionalStationObservation) -> String {
        var components = [observation.station.name(lang: settings.apiLanguageCode),
                          settings.measurement(observation.reading?.value, unit: observation.reading?.unit)]
        if favoriteIDs.contains(observation.id) { components.append(settings.text("explorer_favorite_badge")) }
        return components.joined(separator: ", ")
    }
}
