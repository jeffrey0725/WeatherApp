# WeatherApp

Last updated: 2026-10-19 09:32:03 HKT (UTC+08:00)

A native iOS app for Hong Kong weather, built with SwiftUI and Hong Kong Observatory (HKO) open data. The current deployment target is iOS 17.6 and the project uses Swift 5 language mode.

## Project documents

- [Handover notes](docs/HANDOVER.md): architecture, data handling, development notes, and validation limits.
- [Status and progress](docs/STATUS.md): completed features, open issues, validation evidence, and next priorities.
- [Rainfall station reference](docs/RAINFALL_STATIONS.md): official coordinate sources and verified spatial/API ID matching.
- [Project instructions](AGENTS.md): working constraints and documentation timestamp rules.

## Current features

- Today dashboard with Observatory temperature, humidity, UV information, warnings, local forecast, and a three-day forecast preview.
- Sunrise/sunset card with Hong Kong event times, daylight duration/progress, and a countdown to the next sunrise or sunset.
- Detailed local and nine-day forecasts, with an interactive high/low temperature chart and selected-day details.
- Regional readings, rainfall information, an interactive station map, and a station detail sheet.
- Regional weather explorer with Map/List switching, temperature pins, bilingual station search, an All/Favorites filter, and name/warmest/coolest list sorting.
- Near me weather with a user-triggered location lookup, nearest reporting station, approximate distance, and manual search fallback.
- Past-hour rainfall Map/List views with 36 verified station locations, bilingual search, station details, ranked readings, a bar chart, and explicit zero/maintenance/unavailable states.
- Warning summaries, full warning statements, special weather tips, and pre-No. 8 announcements.
- Favorite stations with custom labels, ordering, deletion, and local SwiftData persistence.
- Follow-device, English, and Traditional Chinese language settings.
- Celsius/Fahrenheit preferences for numeric temperature readings and ranges.
- Appearance preference in Settings: follow the device's light/dark setting, or force Light or Dark.
- Pull-to-refresh, loading states, retry actions, and localized network errors.
- Previous warning reports are labeled explicitly when a refresh fails; an unavailable current status is not presented as an all-clear result.

The app disables weather API response caching. Existing in-memory readings can remain visible after a failed refresh; this behavior and the remaining fresh-fetch gaps are recorded in [STATUS.md](docs/STATUS.md).

Open **Today → Weather around Hong Kong** to use the explorer. Choose Map or List; both share bilingual search and the All/Favorites filter. The list shows matching stations, including unavailable readings, and offers station-name, warmest-first, and coolest-first sorting. Temperature sorts place missing readings last. Tap a temperature pin or list row for the same station sheet and favorite actions; unavailable stations can also be favorited. The reading and its observation time are captured together when opening the sheet. The information button opens the complete regional report. View changes, sorting, search, and filters use the loaded report; opening the explorer, refreshing it, changing language, or returning from the background requests fresh HKO data without caching. Empty favorites, unmatched names, and unavailable measurements have separate states.

In the explorer, tap **Near me → Find nearby station** to request When In Use location access and fresh HKO readings. The card finds the closest station with a usable temperature within 50 km, independently of the search/favorites filter. Open its details for favorite actions, or choose Show on map to focus the station. Approximate location is supported; denial, restrictions, timeout, missing readings, and distant locations leave manual search available. The app does not save coordinates or include them in HKO weather requests. Location lookup stops after one result and is canceled/cleared on background or screen exit; no Always access or background location mode is used.

Open **Today → Past-hour rainfall**, or find it in Browse reports, to compare rainfall stations. Choose Map or List; both share English/Chinese name and rainfall-ID search. The map uses 36 verified HKO rainfall locations and distinguishes measured rain, genuine zero, maintenance, and unavailable readings. Tap a pin or list row for its recorded one-hour window and reading. List retains the ranking and chart of up to five stations with measured rain. Future stations without verified coordinates remain in List, with their count shown in Map. Rainfall stays in millimetres regardless of the temperature preference. Entry, refresh, language change, and return from the background request fresh data. See the [coordinate source and ID reference](docs/RAINFALL_STATIONS.md).

The **Today → Sunrise & sunset** card uses HKO’s solar event dataset for today and tomorrow. It shows the date and Hong Kong time, daylight duration, a daylight progress bar, and the time remaining until the next event. The countdown updates once per minute. Missing times stay unavailable; if tomorrow’s request fails, today’s times remain usable. Today requests fresh weather and solar data on load, pull/manual refresh, language change, and return from the background. The visible solar card also triggers a refresh when the Hong Kong date changes.

Open **Today → View nine-day forecast**, or **Browse reports → Nine-day forecast**, for the temperature trend. Tap the chart or choose a date button to see that day’s weather, temperature, humidity, wind, and HKO rain-likelihood category. Swipe horizontally to see all dates; the complete forecast list remains below. The chart follows the language and Celsius/Fahrenheit preferences, leaves gaps for missing values, and never substitutes zero. Entry, manual/pull refresh, language change, and return from the background request fresh HKO data without caching. Failed refreshes label the retained forecast as previous data.

## Generate, open and run

Ensure XcodeGen 2.46.0 or later is available on your PATH, then run this from the project root:

```sh
bash scripts/generate-project.sh
```

The wrapper generates [WeatherApp.xcodeproj](WeatherApp.xcodeproj) from [project.yml](project.yml) and keeps XcodeGen's temporary files and cache under `.build/validation/xcodegen/`.

1. Open the generated `WeatherApp.xcodeproj` in Xcode.
2. Select the `WeatherApp` scheme and an iOS 17.6 or later destination.
3. For your own signing team, change `DEVELOPMENT_TEAM` in `project.yml` and regenerate. The spec currently preserves the original project's team and bundle IDs.
4. Build and run the app.

Use an Xcode installation with the SwiftUI and SwiftData APIs used by this project. The shared debug scheme currently selects `zh-Hant`; account for that override when testing the follow-device language setting.

[project.yml](project.yml) is the source of truth for the app, unit-test and UI-test targets, build settings, localized resources, and shared scheme. Make durable configuration changes there and regenerate instead of editing the generated project directly. Source directories are scanned automatically, so regenerate after adding or removing files. The generated project remains checked in.

The app and unit-test target explicitly include English and Traditional Chinese Localizable.strings and InfoPlist.strings resources, matching string/purpose lookups and the standalone validator. The location permission message is localized using the language selected by iOS; the app’s own location UI follows its language preference.

For additional configuration options, see the [XcodeGen project specification](https://github.com/yonaskolb/XcodeGen/blob/2.46.0/Docs/ProjectSpec.md).

## Validate without launching a simulator

The existing validator requires macOS 14 or later, a selected Xcode installation, and Python 3. Run it from the project root:

```sh
bash scripts/validate-hko.sh
```

The script runs the service, model, favorites, and settings tests in a standalone macOS XCTest bundle, then typechecks all app Swift sources for an arm64 iOS 17.6 target. It keeps its test bundle, temporary files, persistence fixtures, and compiler module caches in `.build/validation/`, which Git ignores.

Some execution sandboxes require approval for Xcode's SwiftData compiler plugin. The script does not launch Xcode or a simulator. A complete Xcode build and device UI checks are separate validation steps.

The latest validation on **2026-10-19, Hong Kong time**, reported **182 passing tests and passing iOS source typechecks** (180 on 2026-10-18, plus 2 appearance-setting tests), and the simulator UI tests passed. The earlier rainfall work added 11 rainfall-map regressions. All 36 rainfall coordinates and API ID/name matches were checked against the official spatial dataset and live English feed. XcodeGen was rerun and the generated targets include all 47 app, 10 unit-test, and 2 UI-test Swift sources, with localized resources in both app and unit-test targets. A normal iOS Xcode test run and device UI verification remain pending. See [validation details and limitations](docs/STATUS.md#validation-record).

## Run the simulator UI tests

The UI tests need an installed iOS simulator and network access, because they use live HKO data and assert only on structure. They use an in-memory favorites store and forced language/unit/appearance launch arguments, so they leave your saved data alone. Replace the UDID with one from `xcrun simctl list devices available`:

```bash
xcodebuild test -project WeatherApp.xcodeproj -scheme WeatherApp \
  -destination 'id=<simulator UDID>' -derivedDataPath .build/validation/dd \
  -only-testing:WeatherAppUITests CODE_SIGNING_ALLOWED=NO
```

They last passed on 2026-10-18 (iPhone 16 simulator, iOS 18.1). See [STATUS.md](docs/STATUS.md#open-issues) for what they do and do not cover.

## Data and persistence

| Data | Handling |
| --- | --- |
| Weather API responses | Live HKO requests using an ephemeral URLSession, no URL cache, and an explicit reload request policy. |
| Rainfall station locations | Bundled static HKO metadata with a documented spatial/API ID crosswalk; no rainfall responses are bundled or persisted. |
| Favorite stations | Local SwiftData store with explicit saves and rollback on save failure; CloudKit is disabled. |
| Language and temperature unit | UserDefaults preferences. |
| Near me coordinates | Memory only; cleared on background/screen exit, never included in HKO weather requests. |
| Observation times | Displayed in Hong Kong time; kept separate from the app's last successful fetch time. |

Official source: [HKO Open Data API documentation](https://data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf).

## Working constraints

Keep files created by project work inside this repository, including validation output and temporary files. Do not introduce a persistent weather cache or a cache-based fallback without a new user instruction. Preserve existing unrelated working-tree changes.

When changing a document, update its `Last updated` date and time in `Asia/Hong_Kong`, including the timezone. Keep implementation and validation progress current in [STATUS.md](docs/STATUS.md).
