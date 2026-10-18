# Status and progress

Last updated: 2026-10-18 22:17:14 HKT (UTC+08:00)

Current stage: a working Hong Kong weather MVP with a regional weather explorer offering map/list views and Near me weather, a past-hour rainfall Map/List dashboard with station details, a sunrise/sunset card, an interactive nine-day forecast chart, and an XcodeGen build definition. The failed-warning-refresh display issue is addressed in code and regression tests. Broader fresh-fetch/distribution issues and iOS runtime validation remain open.

## Implemented features

| Area | Current implementation |
| --- | --- |
| HKO integration | Six `weather.php` datasets plus dedicated hourly rainfall and SRS solar-time endpoints, shared HTTP/JSON error handling, cancellation handling, localized errors, and disabled weather response caching. |
| Today dashboard | Observatory readings, warnings, favorites, local forecast, three-day forecast preview, and navigation to detailed reports. |
| Detailed reports | Local forecast, nine-day forecast, regional temperature/humidity/UV/rainfall data, and warning statements/tips. |
| Regional explorer/map/list | Shared bilingual search and All/Favorites filtering, map temperature pins, a station list including unavailable readings, name/warmest/coolest sorting, favorite badges, observation times, and a shared station sheet/favorite actions. The explorer owns sheet state; the map remains mounted across display changes. The full regional report remains accessible. |
| Near me | Explicit When In Use one-shot lookup, nearest reporting station within 50 km, metric distance, approximate-location support, details/favorite actions and map focus. Manual search remains available. No coordinate persistence, Always request, continuous tracking, or background location mode. |
| Past-hour rainfall | Today/Browse navigation, Map/List switching with shared bilingual/ID search, 36 verified HKO rainfall locations, explicit positive/zero/maintenance/unavailable markers, captured-reading station sheet, exact API interval, ranked measurements, top-five-positive chart, summary metrics, and unknown-location list fallback. No rainfall favorites. |
| Sunrise/sunset | Today card with Hong Kong date/event times, daylight duration/progress, minute-resolution next-event countdown, optional tomorrow data, unavailable states, and date rollover refresh. |
| Nine-day chart | High/low temperature lines and points, chart-tap/date-button selection, selected-day details, C/F display, Hong Kong dates, missing-value gaps, and the full forecast list below. |
| Favorites | SwiftData persistence, stable station IDs, bilingual station search, custom labels, reordering, deletion, and save rollback. |
| Preferences | Saved Follow device/English/Traditional Chinese selection and Celsius/Fahrenheit display preferences. |
| Refresh behavior | Pull-to-refresh, retries, concurrent dashboard sections, overlapping-request coordination, and language-change cancellation. Today (including solar), nine-day forecast, explorer, standalone warnings, and rainfall also fetch after returning from the background. |
| Warning snapshot state | Shared previous/current/unavailable presentation, snapshot-time expiry evaluation after failed/pending refreshes, historical empty messages, and previous-data labels in linked details. |
| Icon presentation | Removed the separate update timestamp beneath the dashboard's weather icon. |
| Project documentation | README, handover notes, this progress record, and project instructions for future timestamp updates. |
| XcodeGen | Complete app/unit-test/UI-test targets, shared scheme, preserved signing/build settings, automatic source discovery, explicit unit-test localization resources, and a project-contained generation wrapper. |

## Open issues

Priorities: **P1** should be addressed first for user-visible correctness; **P2** is important follow-up work. Distribution items must be resolved before submission.

| ID | Priority | Finding and completion target |
| --- | --- | --- |
| ISSUE-02 | P2 | Partially addressed: Today (including solar), nine-day forecast, explorer, standalone warnings, and rainfall request fresh data after returning from the background. Favorite details still reuse dashboard readings, and older local/full-regional detail screens lack an explicit foreground refresh hook. Complete the remaining entry/return paths while preserving no-cache behavior. See [favorite details](../WeatherApp/CustomView/DashboardFavoriteStationsView.swift) and [HomeView.swift](../WeatherApp/View/HomeView.swift). |
| ISSUE-04 | P2 | Favorites container initialization failure prevents all weather browsing. Provide a deliberate recovery or weather-only path while preserving the existing store. See [WeatherAppApp.swift](../WeatherApp/WeatherAppApp.swift). |
| ISSUE-05 | P2, distribution | No privacy manifest declares the app's UserDefaults usage. Add the appropriate app-bundled declaration and verify its target membership before distribution. See [AppSettings.swift](../WeatherApp/Model/AppSettings.swift) and [Apple's required reason API documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). |
| ISSUE-06 | P2, distribution | Info.plist enables `NSAllowsArbitraryLoads` globally although the app's explicit weather/image URLs use HTTPS. Verify connectivity with normal ATS protections and remove the unnecessary exception. See [Info.plist](../WeatherApp/Info.plist) and [Apple's ATS documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowsarbitraryloads). |
| ISSUE-07 | P2 | UI tests are primarily launch/performance templates. Meaningful device/simulator checks are still needed for refresh behavior, settings changes, favorite operations, map selection, and sheet gestures/layout. See [WeatherAppUITests](../WeatherAppUITests). |

The remaining issues above are open. The October 17 evaluation established the baseline; October 18 work addresses the warning snapshot display and Xcode test resource configuration, as recorded below.

## Addressed findings

| ID | Update | Verification remaining |
| --- | --- | --- |
| ISSUE-01 | Addressed on 2026-10-18: dashboard and standalone warnings share snapshot-state presentation. Failed/pending refreshes label retained reports as previous, evaluate their warnings at the original successful check time, and state that the current status is unconfirmed. A failed initial request cannot display an all-clear result. Six snapshot tests and an end-to-end view-model failure/recovery regression pass. | Device UI verification of banners, linked details, TimelineView expiry, and lifecycle refresh remains pending. Broader foreground-fetch gaps are tracked separately in ISSUE-02. |
| ISSUE-03 | Configuration addressed on 2026-10-18: [project.yml](../project.yml) explicitly includes `WeatherApp/Localization` as unit-test resources. Generated app and unit-test targets both contain English and Traditional Chinese Localizable.strings. The initial 53-test migration check passed; the expanded suite now passes 180 tests. | A normal iOS Xcode test execution is still pending. Static resource membership and standalone tests do not establish that full runtime result. |

## Validation record

Latest validation: **2026-10-18, Asia/Hong_Kong**, during the rainfall map enhancement. Earlier review/migration results remain recorded where relevant; the document timestamp is separate from each validation date.

| Check | Recorded result | Limits / evidence |
| --- | --- | --- |
| `bash scripts/validate-hko.sh` | 180 tests passed, zero failures on 2026-10-18. | Standalone macOS XCTest: 35 weather tests, 9 favorites, 11 settings/coordinator, 20 explorer, 6 warning snapshot, 21 rainfall, 11 rainfall-map, 22 solar, 21 forecast-chart, and 24 nearby/location tests. Tests inject a fake location client and make no real location request. Latest log: `.build/validation/rainfall-map.log`. Previous 169-test Near me result: `.build/validation/nearby.log`; 145-test map/list result: `.build/validation/explorer-list.log`; 133-test forecast-chart result: `.build/validation/forecast-chart.log`; 112-test solar result: `.build/validation/solar.log`; 90-test rainfall result: `.build/validation/rainfall.log`; 69-test explorer result: `.build/validation/explorer.log`; 53-test migration result: `.build/validation/xcodegen/validation.log`. |
| iOS source typecheck | Passed. | All app Swift sources checked for arm64 iOS 17.6; not a full Xcode build, resource validation, or device run. |
| Property list/localization syntax | Passed. | Xcode project, Info.plist, and English/Traditional Chinese Localizable.strings were checked. |
| XcodeGen generation | Passed with XcodeGen 2.46.0; regenerated after adding rainfall-map model/view/sheet/tests and the coordinate reference. | The earlier migration also verified repeated generation produced an identical project/scheme. |
| Generated configuration/localization | Passed. | Verified all 47 app, 10 unit-test, and 2 UI-test Swift sources, English/Traditional Chinese Localizable.strings and InfoPlist.strings in app/unit-test resource phases, and 178 matching unique localization keys with all literal text lookups resolved. Latest log: `.build/validation/rainfall-map-project-checks.log`. The previous Near me check verified only the When In Use location purpose remains, with no Always request, continuous updates, or background location mode. Earlier scheme/dependency/settings checks: `.build/validation/xcodegen/project-checks.log`. |
| Rainfall coordinate/identity audit | Passed on 2026-10-18. | All 36 Swift catalog locations equal the official spatial GeoJSON points; each spatial `data_url` filename ID and station name matches the live English hourly API. Spatial layer IDs differ from API IDs and are deliberately not used as join keys. Linked Sha Tin and Shui Pin Wai JSON files were also retrieved. Durable sources/crosswalk: [RAINFALL_STATIONS.md](RAINFALL_STATIONS.md). Research files and detailed checks remain local under `.build/validation/`. |
| XcodeGen migration preservation, historical | Passed for all 44 then-existing app/test source and resource files. | Recorded during the earlier migration, before the intentional source changes for the explorer. Xcode user-state files were retained; a newer workspace UI-state update was left intact. Original migration snapshot: `.build/validation/xcodegen/original/`. |
| Test resource-equivalence reproduction, historical | Failed as expected on 2026-10-17: 1 selected localization test, 6 assertion failures. | Reused the compiled test bundle without the resources then absent from the Xcode test target. This was the original evidence for ISSUE-03, whose configuration is now addressed. Local log: `.build/validation/resource-parity.log`. |
| Full Xcode build / normal Xcode test run | Not verified in the review. | Standalone test success must not be reported as a successful full Xcode run. |
| iOS runtime and visual checks | Pending. | No simulator/device was launched during the project-contained review. |

These local logs are ignored build output and are not guaranteed to exist in a fresh checkout. The [validator](../scripts/validate-hko.sh) can recreate its test results; the resource-equivalence reproduction was a separate review check.

App tests were rerun for the rainfall map enhancement. Project/localization syntax, Markdown links, timestamp metadata, and whitespace are also checked before handover. No simulator/device or full Xcode build was run; native location permission/Settings flows, approximate location, nearby map focus/cancellation, map/list switching, camera retention, list accessibility, final-favorite sheet behavior, forecast chart taps/scrolling/VoiceOver, solar layout/countdown/date rollover, rainfall map/chart/sheet gestures and layout, navigation, and foreground interactions are implemented but not runtime-verified. The documented SRS JSON shape was checked against a live HKO response on 2026-10-18; regression tests use mocked responses.

## Next priorities

The explorer Map/List views and Near me weather, rainfall Map/List/chart and station sheet, sunrise/sunset card, and nine-day forecast chart are implemented in source. Their native runtime checks remain pending. No further feature delivery dates are assigned.

| Work | Scope | State |
| --- | --- | --- |
| Fresh-fetch consistency | Complete older local/full-regional foreground and favorite-detail entry paths while preserving the no-weather-cache requirement. | Open: ISSUE-02. |
| Favorites-store recovery | Keep weather browsing available when favorites persistence cannot open; preserve the existing store. | Open: ISSUE-04. |
| Device validation and distribution | Verify map/sheet/refresh/accessibility flows, then address the privacy declaration and ATS findings before release. | Pending: ISSUE-05, ISSUE-06, ISSUE-07. |

## Progress log

| Date (Hong Kong) | Work recorded |
| --- | --- |
| 2026-10-18 | Added rainfall Map/List switching with 36 verified HKO rainfall locations, shared bilingual/ID search, zero/maintenance/unavailable markers, unknown-location list fallback, and a captured-reading station sheet. Verified the spatial data_url-to-API ID/name crosswalk and documented all coordinates. Added 11 regressions, regenerated XcodeGen, and passed 180 tests plus iOS source checks. Native map/sheet/gesture/accessibility validation remains pending. |
| 2026-10-18 | Implemented Near me weather with an explicit one-shot location request, fresh HKO readings, nearest reporting station within 50 km, approximate metric distance, manual fallback, shared details/favorite actions and map focus. Replaced the unused continuous/Always location flow, localized the When In Use purpose, and added quality/timeout/cancellation/expiry handling. Added 24 fake-client/model/resource regressions, regenerated XcodeGen, and passed 169 tests plus iOS source checks. Native location/UI verification remains pending. |
| 2026-10-18 | Added regional Map/List switching with shared search/favorites, list rows for unavailable stations, name/warmest/coolest sorting, favorite badges, accessible row layouts, and a shared explorer-owned station sheet. The map stays mounted across view changes, and unavailable detail selections have no invented observation timestamp. Added 12 explorer regressions, regenerated XcodeGen, and passed 145 tests plus iOS source checks. Device switching/camera/sheet/accessibility checks remain pending. |
| 2026-10-18 | Added the interactive nine-day high/low chart with chart/date-button selection, selected-day details, C/F conversion, Hong Kong dates, explicit missing-value gaps, and retained full report. The nine-day screen now refreshes after returning from the background and labels retained reports during failed/pending refreshes. Added 21 chart regressions, regenerated XcodeGen, and passed 133 tests plus iOS source checks. Device gestures/layout/accessibility remain pending. |
| 2026-10-18 | Implemented the Today sunrise/sunset card using HKO SRS data, Hong Kong date/time validation, daylight duration/progress, next-event countdown, optional tomorrow data, and midnight rollover handling. Today now refreshes after returning from the background. Added 22 solar regressions, regenerated XcodeGen, and passed 112 tests plus iOS source checks. Device UI verification remains pending. |
| 2026-10-18 | Implemented the dedicated past-hour rainfall dashboard, bilingual search aliases for 36 rainfall station IDs, valid-reading ranking and chart, exact observation interval, explicit maintenance/unavailable states, and live entry/refresh/language/foreground requests. Added 21 rainfall regressions, regenerated XcodeGen, and passed 90 tests plus iOS source checks. Device UI verification remains pending. |
| 2026-10-18 | Implemented the regional explorer with temperature pins, bilingual search, favorites filtering, distinct empty/reading states, and fresh entry/refresh/language/foreground requests. Reused the station sheet, retained access to the full report, fixed failed-warning-refresh snapshot presentation, regenerated XcodeGen, and passed 69 tests plus iOS source checks. Device UI verification remains pending. |
| 2026-10-18 | Migrated the build definition to XcodeGen, regenerated the checked-in project, added a project-contained generation wrapper, preserved all three targets/settings/source files/user state, corrected unit-test localization resource membership, and reran 53 tests plus iOS source checks successfully. |
| 2026-10-18 | Added README, handover notes, status/progress tracking, and project instructions requiring current Hong Kong timestamps on documentation edits. No app behavior changed. |
| 2026-10-17 | Evaluated the project, recorded 53 passing standalone tests and passing iOS source checks, reproduced the localization test resource mismatch, and identified the open issues above. Regional weather explorer was recommended as the next enhancement. |
| 2026-10-14 | Removed the update timestamp beneath the weather icon. Existing features at this baseline already include the dashboard, SwiftData favorites, regional sheet redesign, live-response policy, and language/unit settings. |

For architecture and continuation notes, see [HANDOVER.md](HANDOVER.md). Update this document when implementation status, known issues, or validation evidence changes, and refresh its `Last updated` timestamp at the same time.
