import SwiftUI

struct DashboardSolarTimesView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var viewModel: SolarTimesViewModel
    let isRefreshing: Bool
    let retry: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            WeatherDashboardSectionView(title: "solar_title", section: viewModel.section,
                                        isRefreshing: isRefreshing, retry: retry) { snapshot in
                content(snapshot, at: context.date)
            }
            // A visible Today screen also needs a fresh request at Hong Kong midnight.
            .onChange(of: SolarDay.calendar.startOfDay(for: context.date)) { _, _ in retry() }
        }
    }

    private func content(_ snapshot: SolarTimesSnapshot, at now: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(SolarTimesFormatting.date(snapshot.today.date, locale: settings.locale)) · \(settings.text("solar_hong_kong_time"))")
                .font(.caption).foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                      alignment: .leading, spacing: 16) {
                event("solar_sunrise", icon: "sunrise.fill", time: snapshot.today.sunrise)
                event("solar_sunset", icon: "sunset.fill", time: snapshot.today.sunset)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(settings.text("solar_daylight_duration")).font(.subheadline)
                Spacer(minLength: 8)
                Text(snapshot.today.daylightDuration.map { SolarTimesFormatting.duration($0, locale: settings.locale) }
                     ?? settings.text("weather_unavailable"))
                    .font(.subheadline.bold())
            }
            .accessibilityElement(children: .combine)

            if let progress = snapshot.today.daylightProgress(at: now) {
                VStack(alignment: .leading, spacing: 8) {
                    let isDaylight = snapshot.today.sunrise.map { now >= $0 } == true
                        && snapshot.today.sunset.map { now < $0 } == true
                    Label(settings.text(isDaylight ? "solar_daytime" : "solar_nighttime"),
                          systemImage: isDaylight ? "sun.max.fill" : "moon.stars.fill")
                        .font(.subheadline).foregroundStyle(isDaylight ? .orange : .secondary)
                    ProgressView(value: progress)
                        .tint(.orange)
                        .accessibilityLabel(settings.text("solar_daylight_progress"))
                        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0)).locale(settings.locale)))
                    Text(settings.text("solar_daylight_progress")).font(.caption).foregroundStyle(.secondary)
                }
            }

            if let next = snapshot.nextEvent(at: now) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(next.kind == .sunrise ? "solar_until_sunrise" : "solar_until_sunset"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(SolarTimesFormatting.duration(next.time.timeIntervalSince(now), locale: settings.locale))
                        .font(.title3.bold()).monospacedDigit()
                    Text(settings.timestamp(next.time)).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(settings.text(SolarDay.calendar.isDate(snapshot.today.date, inSameDayAs: now)
                                   ? "solar_next_unavailable" : "solar_day_changed"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func event(_ title: String, icon: String, time: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(settings.text(title), systemImage: icon).font(.subheadline).foregroundStyle(.secondary)
            Text(time.map { SolarTimesFormatting.time($0, locale: settings.locale) }
                 ?? settings.text("weather_unavailable"))
                .font(.title2.bold()).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
