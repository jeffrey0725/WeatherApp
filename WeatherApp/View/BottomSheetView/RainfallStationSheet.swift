import SwiftUI

struct RainfallStationSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let selection: RainfallStationSelection
    let isPrevious: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selection.reading.name(lang: settings.apiLanguageCode))
                            .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(selection.id).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.text("weather_close"))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label(settings.text("rainfall_amount"), systemImage: "cloud.rain")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(selection.reading.displayText(settings: settings))
                        .font(.largeTitle.bold()).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text(settings.text("rainfall_period")).font(.subheadline.bold())
                    Text("\(settings.timestamp(selection.observationPeriod.start)) – \(settings.timestamp(selection.observationPeriod.end))")
                        .font(.subheadline)
                    Text(settings.text("rainfall_period_help")).font(.caption).foregroundStyle(.secondary)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                if isPrevious {
                    Text(settings.text("weather_previous_data")).font(.caption).foregroundStyle(.secondary)
                    if let checked = selection.lastChecked {
                        Text("\(settings.text("weather_last_checked")): \(settings.timestamp(checked))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if RainfallStationCatalog.locations[selection.id] == nil {
                    Text(settings.text("rainfall_location_unavailable")).font(.caption).foregroundStyle(.secondary)
                }
                Text(settings.text("weather_data_source")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(480), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Color(.systemBackground))
        .presentationContentInteraction(.resizes)
    }
}
