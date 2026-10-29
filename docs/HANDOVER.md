# Handover notes

Last updated: 2026-10-30 02:13:45 HKT (UTC+08:00)

This handover describes the current source tree. [STATUS.md](STATUS.md) is the record of outstanding issues and validation results; proposed features there are not implemented or scheduled.

## Product scope and user decisions

- Focus on Hong Kong weather and official HKO data.
- Fetch fresh weather data on load/refresh; do not add weather response caching or an offline weather store.
- Persist favorites with SwiftData and simple language/unit/appearance preferences with UserDefaults.
- Keep all files created during development inside the project folder. Use `.build/validation/` for local validation artifacts and temporary files.
- Include a current Hong Kong date/time on every document created or edited. The durable maintenance instructions are in [AGENTS.md](../AGENTS.md).

The network layer already disables response caching. Today (including solar data), the nine-day forecast, explorer, standalone warning screen, and rainfall dashboard refresh after a background-to-active transition. Local forecast, full regional report, and favorite-detail screens also refresh on entry and foreground return (ISSUE-02, device verification pending).

## Architecture and entry points

| File or directory | Responsibility |
| --- | --- |
| [project.yml](../project.yml) and [generate-project.sh](../scripts/generate-project.sh) | XcodeGen target/settings/scheme definition and regeneration wrapper; generation output and cache stay inside the project. |
| [WeatherAppApp.swift](../WeatherApp/WeatherAppApp.swift) | Creates settings and the favorites ModelContainer; injects settings, locale, and persistence into the root view. |
| [HomeView.swift](../WeatherApp/View/HomeView.swift) | Today dashboard, report navigation, Settings presentation, and dashboard refresh actions. |
| [RegionalWeatherExplorerView.swift](../WeatherApp/View/RegionalWeatherExplorerView.swift) and [RegionalWeatherExplorer.swift](../WeatherApp/Model/RegionalWeatherExplorer.swift) | Regional shortcut destination, shared map/list search/favorites, station availability/sorting, explorer-owned sheet selection, and fresh current-report loading. |
| [LocationManager.swift](../WeatherApp/Manager/LocationManager.swift), [NearbyWeather.swift](../WeatherApp/Model/NearbyWeather.swift), and [NearbyWeatherView.swift](../WeatherApp/CustomView/NearbyWeatherView.swift) | One-shot location client/state, permission and cancellation handling, nearest available HKO station matching, freshness gating, and the explorer’s Near me card. |
| [RegionalStationListView.swift](../WeatherApp/CustomView/RegionalStationListView.swift) | Station rows with localized temperatures, favorite badges, accessible text layouts, and selection of available/unavailable stations. |
| [HourlyRainfallView.swift](../WeatherApp/View/HourlyRainfallView.swift) and [HourlyRainfallViewModel.swift](../WeatherApp/ViewModel/HourlyRainfallViewModel.swift) | Dedicated live rainfall Map/List screen, observation period, shared search, summary metrics, ranking/chart, sheet ownership, and refresh/error state. |
| [HourlyRainfall.swift](../WeatherApp/Model/HourlyRainfall.swift) and [RainfallStationCatalog.swift](../WeatherApp/StaticFile/RainfallStationCatalog.swift) | Rainfall response validation, measured/maintenance/unavailable readings, ranking, rainfall-specific bilingual aliases, and verified static coordinates. |
| [RainfallMap.swift](../WeatherApp/Model/RainfallMap.swift), [RainfallMapView.swift](../WeatherApp/CustomView/RainfallMapView.swift), and [RainfallStationSheet.swift](../WeatherApp/View/BottomSheetView/RainfallStationSheet.swift) | Shared rainfall map/list results, captured reading/interval selections, accessible pins, and rainfall station details. |
| [SolarTimes.swift](../WeatherApp/Model/SolarTimes.swift), [SolarTimesViewModel.swift](../WeatherApp/ViewModel/SolarTimesViewModel.swift), and [DashboardSolarTimesView.swift](../WeatherApp/CustomView/DashboardSolarTimesView.swift) | HKO SRS table decoding, fixed Hong Kong calendar/event calculations, coordinated daily requests, and the Today solar card. |
| [NineDayForecastChart.swift](../WeatherApp/Model/NineDayForecastChart.swift), [NineDayForecastChartView.swift](../WeatherApp/CustomView/NineDayForecastChartView.swift), and [NineDayWeatherInfoView.swift](../WeatherApp/View/NineDayWeatherInfoView.swift) | Forecast date/temperature validation, chart series gaps, selection, and detailed nine-day presentation with fresh loading. |
| [WeatherWarningSnapshot.swift](../WeatherApp/Model/WeatherWarningSnapshot.swift) | Shared current/previous/unavailable warning state and snapshot-time expiry evaluation for retained reports. |
| [WeatherDashboardViewModel.swift](../WeatherApp/ViewModel/WeatherDashboardViewModel.swift) | Loads current conditions, local forecast, nine-day forecast, and warning sections concurrently; tracks each section's value, loading state, error, and last successful fetch. |
| [WeatherViewModel.swift](../WeatherApp/ViewModel/WeatherViewModel.swift) | Loads individual detail reports and adds catalog coordinates to regional temperature readings. |
| [WeatherService.swift](../WeatherApp/Service/WeatherService.swift) | HKO requests, HTTP validation, decoding, cancellation checks, and localized user-facing errors. |
| [WeatherRequestCoordinator.swift](../WeatherApp/Service/WeatherRequestCoordinator.swift) | Coordinates overlapping refreshes and superseding language changes. |
| [WeatherModel.swift](../WeatherApp/Model/WeatherModel.swift) | API models, flexible response decoding, Observatory reading lookup, and warning helpers. |
| [AppSettings.swift](../WeatherApp/Model/AppSettings.swift) and [Utils.swift](../WeatherApp/Utils.swift) | Saved settings, explicit localization bundle selection, date formatting, and numeric temperature conversion. |
| [FavoriteStationStore.swift](../WeatherApp/Service/FavoriteStationStore.swift) | Favorites CRUD, ordering, explicit saves, rollback, and ModelContainer creation. |
| [Static.swift](../WeatherApp/StaticFile/Static.swift) | Catalog of 27 stations with stable IDs, English/Traditional Chinese names, coordinates, and search. |
| [View](../WeatherApp/View) and [CustomView](../WeatherApp/CustomView) | Screens, dashboard cards, map annotations, station sheets, warnings, and reusable presentation components. |

Data flow: the app provides settings and favorites persistence; view models request HKO data through the service; SwiftUI presents published results. There is no persisted weather-response layer.

## HKO integration

Base URL: `https://data.weather.gov.hk/weatherAPI/opendata/weather.php`

| `dataType` | Service method | Purpose |
| --- | --- | --- |
| `flw` | `localForecast(lang:)` | Local weather forecast. |
| `fnd` | `nineDayForecast(lang:)` | Nine-day forecast. |
| `rhrread` | `currentReport(lang:)` | Current observations and regional readings. |
| `warnsum` | `warningSummary(lang:)` | Warning summary keyed by warning statement code. |
| `warningInfo` | `warningInformation(lang:)` | Full warning statements and pre-No. 8 announcements. |
| `swt` | `specialTips(lang:)` | Special weather tips. |

The UI selects `en` or `tc`. The service passes the requested language through to HKO. `warningReport(lang:)` loads the three warning endpoints concurrently and publishes their combined result only if all three succeed.

The additional `hourlyRainfall(lang:)` method calls the sibling endpoint `https://data.weather.gov.hk/weatherAPI/opendata/hourlyRainfall.php` with only a `lang` query parameter. It shares the existing HTTPS/HTTP/decode/cancellation handling and no-cache request policy. For injected base URLs, the sibling endpoint preserves the base directory. WeatherDataType still describes only the original six `weather.php` datasets.

The additional `solarTimes(on:)` method calls the sibling `opendata.php` endpoint with `dataType=SRS`, the Hong Kong `year`/`month`/`day`, and `rformat=json`. This dataset has no language query; presentation and request errors use the app’s selected language. The method requires one response row matching the requested Hong Kong date. It shares the same no-cache/HTTP/decode/cancellation handling.

The default session is ephemeral, has `urlCache = nil`, and uses `.reloadIgnoringLocalCacheData`. Requests repeat that policy explicitly and use a 30-second timeout. The service accepts a supplied URLSession so tests can mock responses without contacting HKO.

Important data rules:

- Missing measurements remain unavailable; never turn a missing value into zero or substitute another station's reading for the Observatory.
- Current-report message fields can be strings or arrays, and the UV field can be an empty string.
- Rainfall has an observation interval and a maintenance flag; preserve both.
- Forecast rain likelihood (`PSR`) is a qualitative category, not a percentage.
- Numeric temperature conversion changes presentation only. Official forecast paragraphs keep their original wording and units.
- Measurement `recordTime`, report `updateTime`, and the app's `lastChecked` are different timestamps. The separate timestamp beneath the weather icon has been removed.
- Match warnings to the current subtype when selecting full statements. Pre-No. 8 announcements may exist without a warning-summary entry.

Reference: [HKO API documentation](https://data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf).

## Refresh and concurrency behavior

The request coordinator belongs to each view model. Same-language overlapping callers await the existing task, so a refresh indicator does not finish before the active request. A language change cancels and awaits the previous task before starting the replacement. The rapid English → Chinese → English cancellation case has regression coverage.

View models clear content from the previous language before loading the replacement. Same-language failures retain the last successful in-memory value. The explorer marks retained observations as previous with their last successful check time.

Dashboard cards (WeatherDashboardSectionView, the favorites card) show the Loading row only when they hold no data yet, and the Today list is a plain VStack; keep card heights stable while refreshing or the pull-to-refresh scroll position does not recover. Both warning screens now share DashboardWarningsView and WeatherWarningSnapshot. On the Today dashboard, retained warning records are labeled previous only after a failed refresh, so the card keeps its height during pull-to-refresh and the scroll position returns afterwards; the standalone warnings screen still labels them previous while a refresh is pending. After failure (and on the standalone screen during a refresh), retained warning records are evaluated at their last successful check time and labeled as historical, with an explicit unconfirmed-current-status message. A previous empty report uses the historical empty message. Without a successful snapshot, no current all-clear message is shown. Linked warning/tip details also carry the previous-data label. A TimelineView reevaluates successful snapshots' expiries once per minute. This addresses ISSUE-01's failed-refresh case; it does not resolve the broader foreground-fetch gaps on older screens.

The `refreshWeatherOnActivation` modifier in WeatherStatusView records a background transition and triggers a fresh request on the next active phase. It is currently applied to Today, the nine-day forecast, explorer, standalone warning screen, and rainfall dashboard. Initial loads and language changes still use `.task(id:)`; overlapping requests are coordinated normally. It is also applied to the local forecast, full regional report, and favorite-detail screens.

The coordinator currently keys work by language, not endpoint. Detail screens each own a view model. If a future screen uses one WeatherViewModel to load multiple report types simultaneously, revisit coordination so distinct endpoint operations are not coalesced together.

## Favorites and settings

FavoriteStation stores a unique catalog `stationID`, a user label, and `sortOrder`. Use catalog IDs for saved identity; API TemperatureData UUIDs are temporary view identities. Labels are trimmed, duplicate adds preserve existing labels/order, and failed saves roll back changes. Persistence tests cover reopening a real disk store.

CloudKit is disabled and autosave is disabled; mutations go through explicit saves in FavoriteStationStore. Do not reset or delete a user's store to mask an initialization failure. If the favorites container cannot open, WeatherAppApp falls back to a temporary in-memory store with a Retry banner so weather stays available (ISSUE-04); the on-disk store is untouched.

UserDefaults keys are `weather.settings.language`, `weather.settings.temperatureUnit`, and `weather.settings.appearance`. Unknown values fall back to Follow device, Celsius, and Follow device appearance. Appearance (system/light/dark) maps to `overrideUserInterfaceStyle` on every window (`.unspecified` follows the device), applied from WeatherAppApp on change. Do not use `preferredColorScheme` for this: a presented sheet keeps a forced scheme after it is set back to nil, so Follow device would not restore an open sheet. Colors should stay semantic (`Color(.systemBackground)` etc.); avoid hard-coded light/dark values. AppLocalization chooses the English or Traditional Chinese strings bundle explicitly so changing the SwiftUI locale also changes Foundation-based text lookups.

The regional sheet captures a reading and its observation time together, supports saving/removing favorites, and uses the large presentation size for accessibility text sizes. Device verification of gestures, map interactions, and layout is still pending.

## Regional weather explorer

The Today regional shortcut now opens RegionalWeatherExplorerView; its information button navigates to the existing detailed RegionWeatherInfoView, which remains available through Browse reports too.

RegionalWeatherExplorerResults intersects bilingual catalog search with the optional favorite-ID filter, then matches readings by either station name. Both Map and List use this same result set. Only present numeric measurements become map pins; the list includes all matching catalog stations with missing readings shown as unavailable. Zero remains a real reading, and missing values are counted separately. The displayed station count reflects the visible mode: available pins for Map and all matching rows for List. Coordinates and stable station IDs come from the catalog.

RegionalStationSort offers name, warmest-first, and coolest-first ordering. Name order uses the selected English/Traditional Chinese locale. Temperature order uses available HKO Celsius values, places missing/unsupported-unit values after ranked measurements, and uses name plus stable ID for ties. Zero and negative values remain valid. An unsupported unit can still be displayed as supplied but is not compared numerically with Celsius. Sorting never changes API values; Celsius/Fahrenheit preferences affect presentation only. Search, filtering, sorting, and display changes use the current report without extra network requests. Map/List and sort choices are view-local state, not persisted preferences. No weather cache or new backend was added.

RegionMapView draws temperature capsules and uses stable catalog IDs for known map annotations. Changing displayed station IDs fits the camera to results; normal value refreshes preserve the map position. The explorer keeps the map mounted at zero height while List is visible to retain its camera, with hit testing disabled and accessibility hidden. The list uses LazyVStack rows, minimum 44-point content height, favorite badges, explicit unavailable values, and stacked content at accessibility text sizes. List rows can open details even without a reading so favorite actions remain available.

RegionalStationSelection captures the stable ID, a copy of the displayed reading/catalog name/coordinates, and its observation time together. Missing values keep a nil observation time instead of inheriting a report timestamp. The explorer owns a single sheet for both list rows and map pins, outside filter/result/display conditionals; removing the final favorite should therefore leave the selected snapshot and sheet available. RegionMapView accepts an optional selection callback and highlight ID; its existing internal sheet remains the fallback for the full regional report. Verify camera retention, hidden-map accessibility, and the final-favorite removal interaction on a device.

The view distinguishes no favorites, no matching catalog station, and matching stations without current readings. A failed initial request shows the error/retry state; a failed subsequent request retains clearly labeled previous observations. The explorer requests fresh data on entry, explicit/pull refresh, language change, and return from the background.

## Near me weather

The regional explorer owns LocationManager. Initialization and idle authorization callbacks never request access or a fix. Tapping Find nearby station starts a location lookup and awaits a fresh current-report request concurrently. The near card uses all 27 catalog stations independently of search/favorites. Existing manual search, map/list controls, and reports remain available when location is denied, restricted, unavailable, timed out, expired, or outside the supported reporting radius.

LocationRequestClient isolates the system driver from the test client. The app’s LocationAuthorization enum represents both iOS authorization modes without requiring the macOS test framework’s unavailable When In Use enum case. CoreLocationRequestClient translates native authorization/delegate callbacks to the main actor. It requests When In Use only when explicitly needed, uses `requestLocation()` with hundred-metre desired accuracy, and stops after success/failure/cancellation. An existing Always grant is accepted without requesting or extending it. No continuous updates, Always request, or background location mode is used.

LocationManager permits one active lookup, requests authorization at most once per lookup, suppresses duplicate fix requests from authorization callbacks, and applies a 20-second timeout once authorized. Permission-prompt waiting is cancelable but is not included in that fix timeout. Task cancellation and explicit cancellation resume the pending continuation and stop the driver; late callbacks while idle are ignored. A request token prevents a canceled operation from clearing a later lookup’s state. Successful fixes must have valid finite coordinates, nonnegative finite horizontal accuracy, and timestamps no older than 60 seconds or more than 5 seconds in the future. The newest valid fix is selected. Reduced-accuracy fixes are accepted; the UI explains approximation when reported accuracy exceeds 1 km.

NearbyWeatherMatch chooses the closest catalog station with an available Celsius reading, using straight-line Core Location distance and stable-ID tie ordering. Real zeros/negative values remain valid; missing and unsupported-unit readings are skipped. Matches must be within 50 km. This is a station-distance radius, not an administrative Hong Kong boundary check. No nearby reporting station is a distinct state, not a fabricated reading or an arbitrarily distant Hong Kong station.

NearbyWeatherState permits a match only after a successful weather check with no pending load/error. Retained weather after a failed refresh remains visible in the existing explorer with its previous-data caption, but cannot become a current Near me result. A fresh network response retains HKO’s actual observation time; it does not invent a newer measurement timestamp. The card shows station temperature, approximate metric distance, observation time, and the location fix’s separate timestamp. Coordinates remain only in memory, are cleared/canceled on background or explorer exit, and expire for nearby presentation after five minutes. Foreground refresh updates weather without automatically requesting location again. Coordinates are neither persisted nor added to HKO requests.

Details use the shared explorer-owned station sheet and its favorite actions. Show on map selects Map mode, switches to All stations, replaces the search query with the matched station name, and scrolls to the existing map. It does not start another weather request. Native map focus/scrolling and sheet interactions remain pending device checks.

Info.plist now contains only NSLocationWhenInUseUsageDescription; obsolete Always/legacy purpose keys were removed. English and Traditional Chinese InfoPlist.strings resources localize the native prompt according to iOS’s language selection. The app’s own location UI follows AppSettings. XcodeGen includes these tables in app and unit-test resource phases; the standalone validator copies both Localizable and InfoPlist tables. Automated location tests always inject a fake client, so they neither prompt for permission nor request this Mac’s location.

Native permission dialogs, Allow Once/When In Use behavior, denied/restricted/disabled services, Settings return, reduced accuracy, cancellation on background/exit, VoiceOver/large text, and Show on map scrolling are not runtime-verified. Official API references: [one-shot location requests](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()) and [When In Use authorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization()).

## Past-hour rainfall dashboard

The Today shortcut and Browse reports both open HourlyRainfallView. Its own HourlyRainfallViewModel uses the shared request coordinator and WeatherDashboardSection state. The existing card component provides loading, retry, previous-data labeling, and last successful check time. Same-language failures retain the prior in-memory report; language changes clear the previous report before requesting the replacement. A failed initial load never becomes a zero-rainfall report.

HourlyRainfallReport decodes `obsTime` and `hourlyRainfall`. Observation times must be valid ISO 8601, including fractional-second timestamps, and the displayed interval is exactly the hour ending at that API time. Do not replace an older API observation time with the device time: a fresh network request does not imply a newer observation.

Rainfall station IDs must be nonempty and unique. Values are documented integer strings; numeric JSON integers are also accepted. A real nonnegative value with unit `mm` is measured rainfall. `M` in the value or unit means maintenance. Missing, negative, fractional, invalid, or unsupported-unit values remain unavailable. An empty station collection is separate from a valid all-zero report. Malformed report metadata is rejected rather than published as an all-dry success.

RainfallStationCatalog contains 36 rainfall-specific English/Traditional Chinese alias pairs and static WGS84 locations from HKO’s CSDI hourlyRainfall spatial dataset. The spatial layer’s IDs differ from the hourly API IDs: match the ID in each linked `data_url` filename, and verify names. All 36 names and coordinates were checked on 2026-10-18; the full crosswalk, source links, and maintenance instructions are in [RAINFALL_STATIONS.md](RAINFALL_STATIONS.md). No weather readings are bundled. Search matches both aliases, the live API name, or the rainfall station ID, normalizing straight/curly apostrophes. Unknown future IDs retain their live names and measurements in List. Do not merge these IDs with the temperature catalog or favorite station IDs.

Search filters the report locally through RainfallMapResults. List is the default display. Valid readings sort highest first, including genuine zeros, and unavailable stations follow them. Both displays share search and metrics; Map includes only verified locations and explicitly counts stations available only in List. Blue pins show positive readings, teal pins show real zeros, orange `M` indicates maintenance, and gray `—` means unavailable; accessibility values speak the full reading/status. A text legend explains the markers. List retains the chart of up to five positive readings; all-zero measurements and all-unavailable results have different messages. The summary shows a highest single-station value and counts, never a sum across stations. Measurements stay in millimetres when Celsius/Fahrenheit preferences change.

Pin and row selections open a rainfall-specific sheet, without temperature/favorite actions. RainfallStationSelection captures the reading, observation interval, and successful check time together. Refreshes do not replace an open sheet’s reading; pending/failed/replaced or already unconfirmed snapshots receive the previous-data label. Language changes dismiss the selection. The screen owns selection outside result conditions, so empty filters do not dismiss a sheet. The map stays mounted across display changes, hides from accessibility/hit testing in List, and refits only when the set of visible IDs changes, preserving the camera for value-only/ranking updates. The scrollable sheet uses a 44-point close action, resizing detents, and a large detent at accessibility text sizes. Native gesture/layout behavior remains unverified.

The rainfall screen requests fresh data on entry, manual/pull refresh, language change, and return from the background. Today does not request the rainfall endpoint until the user opens that feature. The Map/List toggle and search use the same fetched report without another weather store. Rainfall-specific favorites are not implemented.

Source references: [English rainfall feed](https://data.weather.gov.hk/weatherAPI/opendata/hourlyRainfall.php?lang=en), [Traditional Chinese rainfall feed](https://data.weather.gov.hk/weatherAPI/opendata/hourlyRainfall.php?lang=tc), and [HKO API documentation](https://data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf).

## Sunrise/sunset card

HomeView owns a separate SolarTimesViewModel alongside the existing weather dashboard view model. Its refresh function awaits both models concurrently, so the pull/manual refresh indicator waits for weather and solar requests. Solar failure remains isolated from the weather sections. Today refreshes both models on entry, manual/pull refresh, language change, and return from the background.

SolarTimesResponse decodes HKO’s `fields`/`data` table, resolving `YYYY-MM-DD`, `RISE`, and `SET` by column name. It tolerates reordered/additional columns, accepts empty/null event times as unavailable, and rejects malformed metadata, duplicate dates, invalid dates/times, or a sunrise at/after sunset. Sun transit is not shown. The service rejects empty, multi-row, and wrong-date responses for a requested day.

SolarDay uses a Gregorian calendar fixed to `Asia/Hong_Kong`, independently of the device timezone/calendar. The model calculates daylight duration and clamped daylight progress only from available event times. This is day length, not observed sunshine duration or a physical sun-position calculation. The card labels its date and Hong Kong time explicitly; it does not invent an API update timestamp.

SolarTimesViewModel requests today and tomorrow concurrently on every refresh, without persisting or caching responses. Today must succeed; tomorrow is optional so its failure does not hide today’s events. After sunset, a missing tomorrow sunrise produces a next-event-unavailable message rather than reusing today’s sunrise. Same-day failures retain a labeled previous snapshot; language/date changes clear the prior section. An injected clock makes Hong Kong midnight and year-boundary behavior testable.

DashboardSolarTimesView uses a minute-resolution TimelineView for its countdown/progress. A visible card triggers refresh when the Hong Kong date changes, including an initial error/empty state. Requests that cross midnight are discarded and followed by a request for the new day; a snapshot for another date cannot produce a current countdown or progress value. Next-event times include their date so tomorrow’s sunrise is explicit. Event tiles adapt to available width and progress/countdown have accessibility labels. These UI behaviors remain pending device verification.

Source references: [HKO SRS dataset](https://data.gov.hk/en-data/dataset/hk-hko-rss-times-of-sunrise-suntransit-sunset), [sample day request](https://data.weather.gov.hk/weatherAPI/opendata/opendata.php?dataType=SRS&year=2026&month=10&day=18&rformat=json), and [HKO API documentation](https://data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf). The live sample schema was checked on 2026-10-18; automated regressions use mocked data.

## Interactive nine-day forecast

NineDayWeatherInfoView reuses its existing WeatherViewModel and `fnd` service method. Entry, pull/manual refresh, language change, and return from the background request fresh data through the shared coordinator/no-cache session. It projects the view model’s value/loading/error/lastChecked into WeatherDashboardSectionView. Initial failures do not invent a forecast; same-language failed or pending refreshes label retained chart and list data as previous, with the last successful check time. An empty successful report has its own message.

NineDayForecastChartData derives chart data without changing the API model. It parses exact `yyyyMMdd` dates with a Gregorian calendar fixed to Asia/Hong_Kong, sorts valid dates, and excludes ambiguous duplicate dates. Undated/invalid/duplicate source records remain in the complete forecast list. Date identity persists across changes in order, values, language, and temperature unit. Selection keeps a matching date after a same-language refresh and falls back to the first valid date when that date disappears. A language change clears the prior report while requesting its replacement, so the rebuilt chart starts with its first valid date.

Only present values with unit `C` enter the chart; actual zero and negative values remain valid. An inverted low/high pair is excluded from the chart. Missing/unsupported values never become zero. Each high/low line has separate segments, so a missing value breaks only its own line and a missing calendar day breaks both lines. Isolated valid values remain visible as points. Fahrenheit conversion uses numeric C × 9/5 + 32 for plotted values; labels/details use the existing localized temperature formatter. Official text and HKO’s qualitative PSR rain-likelihood category retain their original wording and units.

NineDayForecastChartView uses native Swift Charts with orange high/circular points and blue low/square points; the low line is dashed. The chart scrolls horizontally when needed. A tap within its plot selects the closest valid forecast date; the overlay uses a tap gesture, leaving scrolling gestures to the surrounding scroll views. Date buttons provide an alternative selection path, minimum 44-point height, localized date/range labels, and selected accessibility traits. A selected-day card shows the existing full weather/humidity/wind/rain details, followed by the full source forecast list in API order. Chart/date selection uses the already loaded response and does not start another network request.

The axes and day buttons use Hong Kong dates. Temperature preference changes update points/axes without replacing source values. Missing chart values and missing usable dates have explicit messages. The native marks have date/high-low/value accessibility labels. Tapping, horizontal/vertical/pull gesture interactions, chart legends, large text, VoiceOver, and lifecycle refresh remain pending device verification; source typechecking and pure-model tests do not establish those UI results.

## Large screens and the iPhone Duo

Layout decisions use the environment's horizontal size class and the width the content area actually gets, never a device name or screen size (Apple's guidance: compact width on the Duo's outer display, regular width on the inner display, and calculate from the scene or container bounds). `AdaptiveLayout.swift` defines the rule (regular horizontal size class and at least 600 pt wide) and two helpers: `TwoColumnWhenWide` (Today: left column conditions, warnings, favorites and shortcuts; right column sunrise/sunset, local forecast, three-day preview and Browse reports) and `onWideLayoutChange`, which reports whether a view is wide enough. Both read the size class and measure width with `onGeometryChange` and switch layouts with `AnyLayout`, so every child keeps its identity (map camera, selection, search text, open sheets) when the width changes, for example when the Duo is folded or unfolded. Do not use `ViewThatFits` for this: it compares ideal widths, and long text never fits, so it always chose the narrow layout.

The regional explorer and the rainfall screen hide the Map/List picker when wide and show the map and the list/ranking together; narrower windows keep the picker and the original single-column behavior. `RegionMapView` no longer sets its own height: callers set it (500 pt in the narrow explorer and the full regional report, 600 pt in the wide explorer). Station sheets keep their detents.

The screens report their active layout to UI tests through the accessibility identifiers `layout.sideBySide` and `layout.single` (`layoutIdentifier(isWide:)`).

iPhone Duo notes (iOS 27.1 simulator, Xcode 27.1): the closed outer display is 466×678 pt (compact width, single column). The open inner display is 669×951 pt, reported as a 951×669 pt window in landscape with SwiftUI content about 867 pt wide next to the side toolbar. The simulator starts closed after a restart; open it with Xcode's Device Hub app (there is no `simctl` fold control). iOS 27 moves navigation controls (BackButton, toolbar items) from the navigation bar into a side `Toolbar` element; the UI tests use `goBack(_:)` for this. Apple's design guideline (Designing for iPhone Duo) and article (Preparing your app for iPhone Duo) were read on 2026-10-23; the follow-ups they imply are listed in STATUS.md. New iOS 27 APIs (`ArrangementView`, `ReservedRegion`) are not used, and the app keeps the iOS 17.6 deployment target. Build with the latest Xcode: Apple says builds from Xcode 26 and earlier do not extend under the status bar and camera. `UIApplicationSupportsMultipleScenes` is already true; settings and the favorites container are app-level and shared, and the appearance setting is applied to all windows. Two windows, Split View, the folded (outer display) state and a physical Duo have not been exercised. The Duo simulator in this environment returns blank screenshots (no Simulator app), so appearance tests that read pixels skip there; layout was inspected through the accessibility tree and on iPad simulators.

## Cards, rainfall pins and toolbars

- Cards and rows that sit on `systemGroupedBackground` use `Color.groupedCard`, with `Color.groupedCardInset` for areas inside a card (defined in AdaptiveLayout.swift). Do not use `secondarySystemBackground` there: it equals the page color in light mode and the card disappears. Screens with a plain (non-grouped) background keep the secondary colors.
- `RainfallMarkerStyle` (RainfallMap.swift, unit tested) switches the rainfall map to small value-only pins when the visible latitude span is above 0.12° (the default territory view is about 0.35°); `RainfallMapView` tracks the span with `onMapCameraChange`. Pin colors are darker than the system colors so white text keeps at least 4.5:1 contrast. The explorer's temperature pins have not been changed and still overlap at the default zoom.
- Toolbar items are `Label`s (title and symbol): the system uses the symbol on the Duo's side toolbar and the title in overflow menus; items with only text or a custom view are not shown vertically. `RefreshToolbarLabel` keeps the symbol while loading (it pulses). `keepVisibleLongest()` applies `visibilityPriority(.high)` on iOS 27 and does nothing earlier. Sheet buttons such as Done, Cancel and Save are still text; on the closed Duo the Settings sheet shows Done in a normal horizontal bar.

## Validation and development notes

Run the project-contained validator using the instructions in [README.md](../README.md#validate-without-launching-a-simulator).

- The suite contains 184 tests (180 listed below plus 2 appearance-setting tests and 2 rainfall-marker tests): 35 weather/service/view-model, 9 favorites, 11 settings/coordinator, 20 explorer filtering/reading/sorting/selection, 6 warning snapshot, 21 hourly rainfall, 11 rainfall-map, 22 solar, 21 forecast-chart, and 24 nearby/location tests.
- The validator builds a standalone macOS XCTest bundle, copies Localizable.strings and InfoPlist.strings resources into that bundle, and then typechecks app sources for iOS 17.6.
- Its 180 passing tests do not establish that a full Xcode test/build or iOS runtime UI flow passes. Rainfall-map regressions cover catalog coverage/bounds, spatial/API identity differences and non-RF IDs, shared search, zero/maintenance/unavailable values, unknown IDs, stable map identity, and captured reading/interval/previous-state snapshots. Rainfall regressions cover timestamp/interval handling, maintenance and invalid values, true zeros, ranking, bilingual search, endpoint/query/cache policy, repeat requests, language changes, and failure/recovery. Solar regressions cover the table schema, missing events, date/time validation, reordered columns, daylight/event boundaries, Hong Kong formatting, endpoint/query/cache policy, repeated loads, partial failure, language/date changes, year boundaries, and in-flight midnight rollover. Forecast-chart regressions cover date validation/order, duplicate dates, zeros/negative/missing/unsupported values, line gaps, C/F conversion, selection, detail preservation, and repeated/failed/language/empty refreshes. The 12 added explorer regressions cover list-versus-map availability, temperature/name ordering, zeros/negatives/unsupported units, bilingual/favorites filtering, stable identity, captured reading/time snapshots, and unavailable selection metadata. The 24 nearby/location regressions cover nearest eligible station matching, distance/radius, location quality/expiry, pending/failed-weather gating, localization resources, idle/requested authorization, one-shot success/retry/timeout, duplicate requests, cancellation, and memory clearing. Native location access is replaced with a fake client in every test. Original explorer and failed-warning-refresh regressions remain in the suite.
- The October 17 review reproduced six failed localization assertions when the test bundle lacked its strings. The October 18 XcodeGen migration explicitly adds the English and Traditional Chinese resources to the unit-test target and verifies their membership (`ISSUE-03`, configuration addressed). A normal iOS Xcode test run remains pending.
- UI tests (WeatherAppUITests) run on a simulator against the live HKO feeds and assert structure rather than weather values. The app reads the launch flag `-uitest-in-memory-favorites` to use an in-memory favorites store, and tests force language/unit/appearance through `-weather.settings.language` / `-weather.settings.temperatureUnit` / `-weather.settings.appearance` launch arguments, so they never touch real saved data. Run: `xcodebuild test -project WeatherApp.xcodeproj -scheme WeatherApp -destination 'id=<simulator UDID>' -derivedDataPath .build/validation/dd -only-testing:WeatherAppUITests CODE_SIGNING_ALLOWED=NO`. Coverage and gaps are in ISSUE-07.
- Validation logs under `.build/validation/` are ignored, local evidence and may not be present in another checkout. Keep durable outcomes and their actual validation date in STATUS.md.

[project.yml](../project.yml) is now the build definition. Regenerate the checked-in `.xcodeproj` with `bash scripts/generate-project.sh` after changing settings or adding/removing source files. The wrapper uses a project-local TMPDIR and an explicit cache path under `.build/validation/xcodegen/`. XcodeGen 2.46.0 was used for this migration; the spec requires at least that version and selects the Xcode 16 project format.

The spec preserves all three target names, bundle IDs, the original signing team, iOS 17.6 deployment, Swift 5 language mode, version/build numbers, app assets, Info.plist, and the shared scheme's Traditional Chinese debug launch. Both test targets depend on WeatherApp; unit tests also include the shared localization directory as bundle resources. The debug/release settings and run/test/profile/analyze/archive scheme actions are explicit. App configuration still comes from the existing Info.plist plus generated standard keys; XcodeGen does not overwrite that source plist.

Application and test source directories are scanned automatically. To add a new target, resource outside those directories, or dependency, update the spec. Do not make durable changes only to the generated project. A whole-source typecheck alone cannot verify target membership or bundled resources; validate the generated configuration too.

Existing feature work includes many modified and untracked files. Preserve that work and unrelated Xcode user-state changes; review Git status before starting another task.

## Suggested next work

Complete normal Xcode/device validation of the explorer and warning changes. Check search in both languages, All/Favorites changes, Map/List switching, temperature/name sorting, zero/missing readings, unit changes, pin/row selection, camera retention, removing the final favorite while its sheet is open in either mode, hidden-map VoiceOver behavior, large text, and background/foreground refresh. Also verify that a failed warning refresh labels prior data and never substitutes a current all-clear message. These are pending runtime checks, not claimed test results.

For rainfall, verify Map/List switching and camera retention across value-only refreshes, pan/zoom with vertical scrolling and pull-to-refresh, pin/row selection, resizing/dismissal gestures, empty/unmapped searches, zero/maintenance/unavailable markers and VoiceOver, both languages, large text, chart labels, and foreground refresh. The native map, chart, sheet, and navigation are source-typechecked but not visually verified on a device.

For the solar card, verify English/Traditional Chinese layouts, VoiceOver and large text, before/after sunrise and sunset, missing tomorrow data, background return, and Hong Kong midnight rollover. These remain device/runtime checks.

For the forecast chart, verify chart taps and date buttons select the same day, selected markers and details, horizontal chart scrolling alongside vertical scrolling/pull-to-refresh, both units/languages, missing values, date rollover, large text, VoiceOver, and background return. These remain device/runtime checks.

The explorer Map/List views and Near me weather, rainfall Map/List/chart and station sheet, sunrise/sunset card, and nine-day chart are implemented. Prioritize device validation (ISSUE-07) before adding further features.

For Near me, verify the first tap produces the native permission prompt, opening the explorer alone does not prompt, and returning from Settings or the background does not automatically start location lookup. Check fresh weather failure, approximate location, no available station within 50 km, cancellation, map focus, and favorite actions on a device. The previous unused continuous/Always location implementation has been replaced.

PrivacyInfo.xcprivacy (UserDefaults CA92.1) was added and the global ATS exception removed; verify both in an Xcode archive and on a device before distribution. Official references: [required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [UserDefaults reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), and [NSAllowsArbitraryLoads](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowsarbitraryloads).
