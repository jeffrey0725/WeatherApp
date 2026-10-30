import SwiftUI

struct MoonTimesCardContent: View {
    @EnvironmentObject private var settings: AppSettings
    let snapshot: MoonTimesSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(SolarTimesFormatting.date(snapshot.today.date, locale: settings.locale)) · \(settings.text("solar_hong_kong_time"))")
                .font(.caption).foregroundStyle(.secondary)
            events(snapshot.today)

            if let next = snapshot.nextEvent(at: now) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(next.kind == .moonrise ? "moon_until_rise" : "moon_until_set"))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(SolarTimesFormatting.duration(next.time.timeIntervalSince(now), locale: settings.locale))
                        .font(.title3.bold()).monospacedDigit()
                    Text(settings.timestamp(next.time)).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(settings.text(SolarDay.calendar.isDate(snapshot.today.date, inSameDayAs: now)
                                   ? "moon_next_unavailable" : "moon_day_changed"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if let tomorrow = snapshot.nextDay {
                Divider()
                Text("\(settings.text("times_tomorrow")): \(SolarTimesFormatting.date(tomorrow.date, locale: settings.locale))")
                    .font(.subheadline.bold())
                events(tomorrow)
            }
            Text(settings.text("moon_note")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func events(_ day: MoonDay) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                  alignment: .leading, spacing: 16) {
            event("moon_rise", icon: "moonrise.fill", time: day.moonrise)
            event("moon_set", icon: "moonset.fill", time: day.moonset)
        }
    }

    // A blank cell is a date without that event, not missing data, so it is not called unavailable.
    private func event(_ title: String, icon: String, time: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(settings.text(title), systemImage: icon).font(.subheadline).foregroundStyle(.secondary)
            if let time {
                Text(SolarTimesFormatting.time(time, locale: settings.locale)).font(.title2.bold()).monospacedDigit()
            } else {
                Text(settings.text("moon_none")).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TideTimesCardContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let snapshot: TideTimesSnapshot
    let now: Date

    var body: some View {
        let events = snapshot.events
        let next = snapshot.nextEvent(at: now)
        VStack(alignment: .leading, spacing: 16) {
            Text("\(snapshot.station.name(lang: settings.apiLanguageCode)) · \(SolarTimesFormatting.date(snapshot.today.date, locale: settings.locale)) · \(settings.text("solar_hong_kong_time"))")
                .font(.caption).foregroundStyle(.secondary)

            if let next {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(untilKey(next.kind))).font(.subheadline).foregroundStyle(.secondary)
                    Text(SolarTimesFormatting.duration(next.time.timeIntervalSince(now), locale: settings.locale))
                        .font(.title3.bold()).monospacedDigit()
                    Text("\(settings.timestamp(next.time)) · \(height(next.heightMeters))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(settings.text(SolarDay.calendar.isDate(snapshot.today.date, inSameDayAs: now)
                                   ? "tide_next_unavailable" : "tide_day_changed"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Divider()
            list("times_today", date: snapshot.today.date, events: events, next: next)
            if let tomorrow = snapshot.nextDay {
                list("times_tomorrow", date: tomorrow.date, events: events, next: next)
            }
            Text(settings.text("tide_note")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func list(_ titleKey: String, date: Date, events: [TideEvent], next: TideEvent?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(settings.text(titleKey)): \(SolarTimesFormatting.date(date, locale: settings.locale))")
                .font(.subheadline.bold())
            ForEach(events.filter { SolarDay.calendar.isDate($0.time, inSameDayAs: date) }) { event in
                row(event, isNext: event.id == next?.id)
            }
        }
    }

    private func row(_ event: TideEvent, isNext: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Label {
                Text(settings.text(titleKey(event.kind)))
            } icon: {
                Image(systemName: event.kind == .high ? "arrow.up" : event.kind == .low ? "arrow.down" : "water.waves")
                    .accessibilityHidden(true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(SolarTimesFormatting.time(event.time, locale: settings.locale)).monospacedDigit()
            Text(height(event.heightMeters)).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(isNext ? .bold : .regular))
        // Tides that have already passed are secondary; the next one is bold.
        .foregroundStyle(event.time <= now ? Color.secondary : Color.primary)
        .accessibilityElement(children: .combine)
    }

    private func height(_ meters: Double) -> String {
        "\(TideFormatting.height(meters, locale: settings.locale)) \(settings.text("tide_unit"))"
    }

    private func titleKey(_ kind: TideEvent.Kind?) -> String {
        switch kind {
        case .high: return "tide_high"
        case .low: return "tide_low"
        case nil: return "tide_unknown"
        }
    }

    private func untilKey(_ kind: TideEvent.Kind?) -> String {
        switch kind {
        case .high: return "tide_until_high"
        case .low: return "tide_until_low"
        case nil: return "tide_until_next"
        }
    }
}
