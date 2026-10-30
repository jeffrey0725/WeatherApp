import Foundation
import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class MoonTidesTests: XCTestCase {
    private var session: URLSession!
    private var service: WeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MoonTidesMockURLProtocol.self]
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
        service = WeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        MoonTidesMockURLProtocol.handler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    // MARK: Moon table

    func testHKOMoonResponseUsesHongKongDateAndIgnoresTransit() throws {
        let day = try XCTUnwrap(decodeMoon(Self.moonBody()).days.first)
        XCTAssertEqual(day.date, Self.date("2026-10-30T00:00:00+08:00"))
        XCTAssertEqual(day.moonrise, Self.date("2026-10-30T21:31:00+08:00"))
        XCTAssertEqual(day.moonset, Self.date("2026-10-30T10:40:00+08:00"))
    }

    func testMoonsetBeforeMoonriseIsValidBecauseTheMoonHasNoSunOrdering() throws {
        // 15 of the 31 dates in October 2026 list the moonset earlier in the day than the moonrise.
        let day = try XCTUnwrap(decodeMoon(Self.moonBody(rise: "21:31", set: "10:40")).days.first)
        XCTAssertLessThan(try XCTUnwrap(day.moonset), try XCTUnwrap(day.moonrise))
    }

    func testBlankMoonEventsMeanNoEventAndNeverMidnight() throws {
        // Real HKO rows for 2026-10-04 (no moonrise) and 2026-10-19 (no moonset).
        let noRise = try XCTUnwrap(decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","TRAN.","SET"],"data":[["2026-10-04","","06:43","13:44"]]}"#).days.first)
        XCTAssertNil(noRise.moonrise)
        XCTAssertEqual(noRise.moonset, Self.date("2026-10-04T13:44:00+08:00"))
        let noSet = try XCTUnwrap(decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","TRAN.","SET"],"data":[["2026-10-19","13:30","19:02",""]]}"#).days.first)
        XCTAssertEqual(noSet.moonrise, Self.date("2026-10-19T13:30:00+08:00"))
        XCTAssertNil(noSet.moonset)
        let nulls = try XCTUnwrap(decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-19",null,null]]}"#).days.first)
        XCTAssertNil(nulls.moonrise)
        XCTAssertNil(nulls.moonset)
    }

    func testReorderedMoonColumnsDoNotSwapEvents() throws {
        let day = try XCTUnwrap(decodeMoon(#"{"fields":["SET","TRAN.","YYYY-MM-DD","RISE"],"data":[["10:40","03:33","2026-10-30","21:31"]]}"#).days.first)
        XCTAssertEqual(day.moonrise, Self.date("2026-10-30T21:31:00+08:00"))
        XCTAssertEqual(day.moonset, Self.date("2026-10-30T10:40:00+08:00"))
    }

    func testMalformedMoonTablesAreRejected() {
        let bodies = ["{}", #"{"fields":[],"data":[]}"#,
                      #"{"fields":["YYYY-MM-DD","RISE","SET","RISE"],"data":[]}"#,
                      #"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-30","21:31"]]}"#,
                      #"{"fields":["RISE","SET"],"data":[["21:31","10:40"]]}"#,
                      Self.moonBody(day: "2026-02-30"), Self.moonBody(day: "2026-13-01"), Self.moonBody(day: "30-10-2026"),
                      Self.moonBody(rise: "24:00"), Self.moonBody(rise: "21:60"), Self.moonBody(rise: "9:30"),
                      Self.moonBody(set: "noon"),
                      #"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-30","21:31","10:40"],["2026-10-30","21:31","10:40"]]}"#]
        for body in bodies { XCTAssertThrowsError(try decodeMoon(body), body) }
    }

    func testEmptyMoonTableIsNotFakeData() throws {
        XCTAssertTrue(try decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","TRAN.","SET"],"data":[]}"#).days.isEmpty)
    }

    func testNextMoonEventIsTheEarliestKnownEventAcrossBothDates() throws {
        let snapshot = try moonSnapshot()   // today: set 10:40, rise 21:31; tomorrow: set 11:32, rise 22:19
        let morning = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T08:00:00+08:00")))
        XCTAssertEqual(morning.kind, .moonset)
        XCTAssertEqual(morning.time, Self.date("2026-10-30T10:40:00+08:00"))
        let afternoon = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T12:00:00+08:00")))
        XCTAssertEqual(afternoon.kind, .moonrise)
        XCTAssertEqual(afternoon.time, Self.date("2026-10-30T21:31:00+08:00"))
        // An event exactly at `now` has happened; the next one is after it, here tomorrow's moonset.
        let atRise = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T21:31:00+08:00")))
        XCTAssertEqual(atRise.kind, .moonset)
        XCTAssertEqual(atRise.time, Self.date("2026-10-31T11:32:00+08:00"))
    }

    func testNextMoonEventSkipsDatesWithoutThatEvent() throws {
        let today = try XCTUnwrap(decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-19","13:30",""]]}"#).days.first)
        let tomorrow = try XCTUnwrap(decodeMoon(#"{"fields":["YYYY-MM-DD","RISE","SET"],"data":[["2026-10-20","14:25","00:50"]]}"#).days.first)
        let snapshot = MoonTimesSnapshot(today: today, tomorrow: tomorrow)
        XCTAssertEqual(snapshot.nextEvent(at: Self.date("2026-10-19T14:00:00+08:00"))?.time,
                       Self.date("2026-10-20T00:50:00+08:00"))
    }

    func testMissingOrWrongTomorrowAndAnotherDateNeverInventAMoonEvent() throws {
        let snapshot = try moonSnapshot()
        let night = Self.date("2026-10-30T22:00:00+08:00")
        XCTAssertNil(MoonTimesSnapshot(today: snapshot.today, tomorrow: nil).nextEvent(at: night))
        XCTAssertNil(MoonTimesSnapshot(today: snapshot.today, tomorrow: snapshot.today).nextEvent(at: night))
        XCTAssertNil(MoonTimesSnapshot(today: snapshot.today, tomorrow: snapshot.today).nextDay)
        XCTAssertNil(snapshot.nextEvent(at: Self.date("2026-10-31T00:00:00+08:00")))
    }

    // MARK: Tide table

    func testHKOTideResponseReadsRepeatedColumnPairsByPosition() throws {
        // Real Cheung Chau row for 2026-10-30.
        let row = try XCTUnwrap(decodeTide(Self.tideBody()).rows.first)
        XCTAssertEqual(row.month, 10)
        XCTAssertEqual(row.day, 30)
        XCTAssertEqual(row.readings.map(\.hour), [6, 13, 16, 23])
        XCTAssertEqual(row.readings.map(\.minute), [26, 40, 8, 23])
        XCTAssertEqual(row.readings.map(\.height), [0.52, 1.62, 1.49, 2.65])
    }

    func testDatesWithFewerTidesIgnoreBlankTrailingPairs() throws {
        // Real Quarry Bay rows: 2026-10-03 has two tides, 2026-10-01 has three.
        let two = try XCTUnwrap(decodeTide(Self.tideBody(day: "03", cells: ["0105", "2.44", "0857", "0.84"])).rows.first)
        XCTAssertEqual(two.readings.count, 2)
        let three = try XCTUnwrap(decodeTide(Self.tideBody(day: "01", cells: ["0614", "0.75", "1311", "1.69", "1702", "1.37"])).rows.first)
        XCTAssertEqual(three.readings.count, 3)
    }

    func testTideDayResolvesInHongKongTimeAndAcceptsMidnight() throws {
        // Tai Po Kau really lists a tide at 00:00.
        let row = try XCTUnwrap(decodeTide(Self.tideBody(cells: ["0000", "2.73", "0558", "0.52", "1247", "1.75", "1554", "1.46"])).rows.first)
        let day = try row.tideDay(year: 2026)
        XCTAssertEqual(day.date, Self.date("2026-10-30T00:00:00+08:00"))
        XCTAssertEqual(day.readings.first?.time, Self.date("2026-10-30T00:00:00+08:00"))
        XCTAssertEqual(day.readings.last?.time, Self.date("2026-10-30T15:54:00+08:00"))
        XCTAssertThrowsError(try decodeTide(Self.tideBody(month: "02", day: "30")).rows[0].tideDay(year: 2026))
        XCTAssertEqual(try decodeTide(Self.tideBody(month: "02", day: "29")).rows[0].tideDay(year: 2028).date,
                       Self.date("2028-02-29T00:00:00+08:00"))
        XCTAssertThrowsError(try decodeTide(Self.tideBody(month: "02", day: "29")).rows[0].tideDay(year: 2027))
    }

    func testMalformedTideTablesAreRejected() {
        let header = #""Month","Date","Time","Height(m)","Time","Height(m)""#
        let bodies = ["{}", #"{"fields":[],"data":[]}"#,
                      #"{"fields":["Month","Date"],"data":[]}"#,
                      #"{"fields":["Month","Date","Time"],"data":[]}"#,
                      #"{"fields":["Date","Month","Time","Height(m)"],"data":[]}"#,
                      #"{"fields":["Month","Date","Height(m)","Time"],"data":[]}"#,
                      "{\"fields\":[\(header)],\"data\":[[\"10\",\"30\",\"0626\"]]}",
                      Self.tideBody(month: "13"), Self.tideBody(month: "00"), Self.tideBody(day: "00"), Self.tideBody(day: "32"),
                      Self.tideBody(month: "ten"),
                      Self.tideBody(cells: ["6:26", "0.52"]), Self.tideBody(cells: ["0626", "0.52", "2460", "1.62"]),
                      Self.tideBody(cells: ["2400", "0.52"]), Self.tideBody(cells: ["06:26", "0.52"]),
                      Self.tideBody(cells: ["0626", ""]), Self.tideBody(cells: ["", "0.52"]),
                      Self.tideBody(cells: ["0626", "high"]), Self.tideBody(cells: ["0626", "nan"]),
                      Self.tideBody(cells: ["0626", "inf"]),
                      Self.tideBody(cells: ["1340", "1.62", "0626", "0.52"]),
                      Self.tideBody(cells: ["0626", "0.52", "0626", "1.62"]),
                      #"{"fields":["Month","Date","Time","Height(m)"],"data":[["10","30","0626","0.52"],["10","30","1340","1.62"]]}"#]
        for body in bodies { XCTAssertThrowsError(try decodeTide(body), body) }
    }

    func testEmptyTideTableIsNotFakeData() throws {
        XCTAssertTrue(try decodeTide(#"{"fields":["Month","Date","Time","Height(m)"],"data":[]}"#).rows.isEmpty)
    }

    func testTideKindsAreInferredFromNeighboursAcrossBothDates() throws {
        let snapshot = try tideSnapshot()
        XCTAssertEqual(snapshot.events.map(\.kind), [.low, .high, .low, .high, .low, .high, .low])
        XCTAssertEqual(snapshot.events(on: Self.date("2026-10-30T00:00:00+08:00")).count, 4)
        XCTAssertEqual(snapshot.events(on: Self.date("2026-10-31T00:00:00+08:00")).count, 3)
    }

    func testTheLastTideOfADayIsClassifiedFromTomorrowAndAloneStaysUnlabeled() throws {
        // A date with a single known tide has no neighbour to compare with.
        let single = try tideDay(day: "30", cells: ["2323", "2.65"])
        let alone = TideTimesSnapshot(station: TideStationCatalog.defaultStation, today: single, tomorrow: nil)
        XCTAssertEqual(alone.events.map(\.kind), [nil])
        let tomorrow = try tideDay(day: "31", cells: ["0600", "0.50", "1300", "1.60"])
        let together = TideTimesSnapshot(station: TideStationCatalog.defaultStation, today: single, tomorrow: tomorrow)
        XCTAssertEqual(together.events.map(\.kind), [.high, .low, .high])
    }

    func testAmbiguousTideSequencesStayUnlabeled() throws {
        let level = try tideDay(day: "30", cells: ["0600", "1.00", "1200", "1.00"])
        XCTAssertEqual(TideTimesSnapshot(station: TideStationCatalog.defaultStation, today: level, tomorrow: nil).events.map(\.kind), [nil, nil])
        // Three rising heights do not alternate: the middle one is neither a high nor a low.
        let rising = try tideDay(day: "30", cells: ["0600", "0.50", "1200", "1.00", "1800", "1.50"])
        XCTAssertEqual(TideTimesSnapshot(station: TideStationCatalog.defaultStation, today: rising, tomorrow: nil).events.map(\.kind),
                       [.low, nil, .high])
    }

    func testNextTideIsTheFirstFutureTideAndCrossesMidnight() throws {
        let snapshot = try tideSnapshot()
        let morning = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T06:00:00+08:00")))
        XCTAssertEqual(morning.time, Self.date("2026-10-30T06:16:00+08:00"))
        XCTAssertEqual(morning.kind, .low)
        let exact = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T06:16:00+08:00")))
        XCTAssertEqual(exact.time, Self.date("2026-10-30T13:31:00+08:00"))
        XCTAssertEqual(exact.kind, .high)
        let late = try XCTUnwrap(snapshot.nextEvent(at: Self.date("2026-10-30T23:56:00+08:00")))
        XCTAssertEqual(late.time, Self.date("2026-10-31T06:58:00+08:00"))
        XCTAssertEqual(late.kind, .low)
    }

    func testMissingOrWrongTomorrowAndAnotherDateNeverInventATide() throws {
        let snapshot = try tideSnapshot()
        let night = Self.date("2026-10-30T23:58:00+08:00")
        let today = snapshot.today
        XCTAssertNil(TideTimesSnapshot(station: snapshot.station, today: today, tomorrow: nil).nextEvent(at: night))
        XCTAssertNil(TideTimesSnapshot(station: snapshot.station, today: today, tomorrow: today).nextDay)
        XCTAssertNil(snapshot.nextEvent(at: Self.date("2026-10-31T00:00:00+08:00")))
    }

    func testTideHeightsAreFormattedWithTwoDecimalsInTheSelectedLocale() {
        for locale in [Locale(identifier: "en_HK"), Locale(identifier: "zh_Hant_HK")] {
            XCTAssertEqual(TideFormatting.height(1.6, locale: locale), "1.60")
            XCTAssertEqual(TideFormatting.height(0.05, locale: locale), "0.05")
            XCTAssertEqual(TideFormatting.height(-0.12, locale: locale), "-0.12")
        }
    }

    // MARK: Stations and settings

    func testTideStationCatalogHasUniqueCodesAndBothNames() {
        let stations = TideStationCatalog.stations
        XCTAssertEqual(stations.count, 14)
        XCTAssertEqual(Set(stations.map(\.id)).count, stations.count)
        XCTAssertEqual(Set(stations.map(\.english)).count, stations.count)
        XCTAssertEqual(Set(stations.map(\.chinese)).count, stations.count)
        for station in stations {
            XCTAssertFalse(station.english.isEmpty)
            XCTAssertFalse(station.chinese.isEmpty)
            XCTAssertEqual(station.name(lang: "en"), station.english)
            XCTAssertEqual(station.name(lang: "tc"), station.chinese)
            XCTAssertEqual(TideStationCatalog.station(withID: station.id), station)
        }
        XCTAssertEqual(TideStationCatalog.defaultStation.english, "Quarry Bay")
        XCTAssertNil(TideStationCatalog.station(withID: "ZZZ"))
        XCTAssertEqual(Set(TideStationCatalog.sortedStations(lang: "en").map(\.id)), Set(stations.map(\.id)))
        XCTAssertEqual(TideStationCatalog.sortedStations(lang: "en").first?.english, "Chek Lap Kok")
    }

    func testMoonAndTideStringsExistInBothLanguages() {
        onMainActor { _ in
            let keys = ["moon_tides_title", "moon_tides_shortcut_description", "moon_title", "moon_rise", "moon_set",
                        "moon_none", "moon_until_rise", "moon_until_set", "moon_next_unavailable", "moon_day_changed",
                        "moon_note", "times_today", "times_tomorrow", "tide_title", "tide_station", "tide_high",
                        "tide_low", "tide_unknown", "tide_until_high", "tide_until_low", "tide_until_next", "tide_unit",
                        "tide_next_unavailable", "tide_day_changed", "tide_note"]
            let settings = AppSettings(storage: MoonTidesMemoryStorage(), localizationBundle: Bundle(for: Self.self))
            for language in [AppLanguage.english, .traditionalChinese] {
                settings.language = language
                for key in keys { XCTAssertNotEqual(settings.text(key), key, "\(key) missing for \(language)") }
            }
            settings.language = .english
            XCTAssertEqual(settings.text("tide_high"), "High tide")
            settings.language = .traditionalChinese
            XCTAssertEqual(settings.text("tide_high"), "高潮")
        }
    }

    // MARK: Service

    func testServiceRequestsMRSInJSONUsingTheHongKongDateAndNoCachePolicy() {
        MoonTidesMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/weatherAPI/opendata/opendata.php")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(try Self.query(request), ["dataType": "MRS", "year": "2026", "month": "10", "day": "30", "rformat": "json"])
            return try Self.response(request, body: Self.moonBody())
        }
        // 22:00 UTC on the 29th is already the 30th in Hong Kong.
        perform { service in _ = try await service.moonTimes(on: Self.date("2026-10-29T22:00:00Z")) }
    }

    func testServiceRequestsHLTWithTheStationCode() {
        MoonTidesMockURLProtocol.handler = { request in
            XCTAssertEqual(try Self.query(request),
                           ["dataType": "HLT", "station": "CCH", "year": "2026", "month": "10", "day": "30", "rformat": "json"])
            return try Self.response(request, body: Self.tideBody())
        }
        perform { service in
            let day = try await service.tideTimes(at: Self.cheungChau, on: Self.date("2026-10-30T12:00:00+08:00"))
            XCTAssertEqual(day.readings.count, 4)
        }
    }

    func testMoonAndTideEndpointsPreserveAnInjectedBasePath() {
        let client = WeatherService(session: session, baseURL: "https://example.com/custom/weather.php")
        MoonTidesMockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "example.com")
            XCTAssertEqual(request.url?.path, "/custom/opendata.php")
            let isTide = try Self.query(request)["dataType"] == "HLT"
            return try Self.response(request, body: isTide ? Self.tideBody() : Self.moonBody())
        }
        perform { _ in
            _ = try await client.moonTimes(on: Self.date("2026-10-30T12:00:00+08:00"))
            _ = try await client.tideTimes(at: Self.cheungChau, on: Self.date("2026-10-30T12:00:00+08:00"))
        }
    }

    func testWrongDateEmptyAndBlankResponsesAreServiceErrors() {
        perform { service in
            let noon = Self.date("2026-10-30T12:00:00+08:00")
            for body in [Self.moonBody(day: "2026-10-29"), #"{"fields":["YYYY-MM-DD","RISE","TRAN.","SET"],"data":[]}"#] {
                MoonTidesMockURLProtocol.handler = { try Self.response($0, body: body) }
                do { _ = try await service.moonTimes(on: noon); XCTFail("Expected moon date validation failure") }
                catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
            }
            for body in [Self.tideBody(day: "29"), Self.tideBody(month: "09"),
                         #"{"fields":["Month","Date","Time","Height(m)"],"data":[]}"#,
                         Self.tideBody(cells: [])] {
                MoonTidesMockURLProtocol.handler = { try Self.response($0, body: body) }
                do { _ = try await service.tideTimes(at: Self.cheungChau, on: noon); XCTFail("Expected tide validation failure") }
                catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
            }
        }
    }

    func testHKOParameterErrorPageAndHTTPFailureUseSharedServiceErrors() {
        perform { service in
            let noon = Self.date("2026-10-30T12:00:00+08:00")
            // HKO answers unknown parameters with HTTP 200 and an HTML page.
            MoonTidesMockURLProtocol.handler = { try Self.response($0, body: "Please include valid parameters in API request.") }
            do { _ = try await service.tideTimes(at: Self.cheungChau, on: noon); XCTFail("Expected invalid data") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .invalidData) }
            MoonTidesMockURLProtocol.handler = { try Self.response($0, body: "{}", status: 503) }
            do { _ = try await service.moonTimes(on: noon); XCTFail("Expected HTTP error") }
            catch { XCTAssertEqual(error as? WeatherServiceError, .httpStatus(503)) }
        }
    }

    func testSolarRequestKeepsItsExistingQueryAfterSharingTheBuilder() {
        MoonTidesMockURLProtocol.handler = { request in
            XCTAssertEqual(try Self.query(request), ["dataType": "SRS", "year": "2026", "month": "10", "day": "30", "rformat": "json"])
            return try Self.response(request, body: #"{"fields":["YYYY-MM-DD","RISE","TRAN.","SET"],"data":[["2026-10-30","06:25","12:09","17:50"]]}"#)
        }
        perform { service in _ = try await service.solarTimes(on: Self.date("2026-10-30T12:00:00+08:00")) }
    }

    // MARK: View model

    func testRefreshLoadsMoonAndTidesForTodayAndTomorrow() {
        MoonTidesMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(model.moon.value?.today.moonrise, Self.date("2026-10-30T21:31:00+08:00"))
            XCTAssertEqual(model.moon.value?.tomorrow?.date, Self.date("2026-10-31T00:00:00+08:00"))
            XCTAssertEqual(model.tides.value?.station.id, "QUB")
            XCTAssertEqual(model.tides.value?.today.readings.first?.heightMeters, 0.60)
            XCTAssertEqual(model.tides.value?.tomorrow?.date, Self.date("2026-10-31T00:00:00+08:00"))
            XCTAssertNotNil(model.moon.lastChecked)
            XCTAssertNotNil(model.tides.lastChecked)
            XCTAssertFalse(model.isLoading)
            XCTAssertNil(model.moon.errorMessage)
            XCTAssertNil(model.tides.errorMessage)
        }
    }

    func testRepeatedRefreshFetchesFreshDataEachTime() {
        let requests = RequestCounter()
        MoonTidesMockURLProtocol.handler = { request in requests.increment(); return try Self.dailyResponse(request) }
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(requests.count, 4, "moon and tides, each for today and tomorrow")
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(requests.count, 8)
        }
    }

    func testTomorrowFailureKeepsTodaysTimesWithoutInventingTheNextEvent() {
        MoonTidesMockURLProtocol.handler = { request in
            if try Self.query(request)["day"] == "31" { throw URLError(.timedOut) }
            return try Self.dailyResponse(request)
        }
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T23:58:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNotNil(model.moon.value?.today)
            XCTAssertNil(model.moon.value?.tomorrow)
            XCTAssertNil(model.moon.value?.nextEvent(at: Self.date("2026-10-30T23:58:00+08:00")))
            XCTAssertNotNil(model.tides.value?.today)
            XCTAssertNil(model.tides.value?.tomorrow)
            XCTAssertNil(model.tides.value?.nextEvent(at: Self.date("2026-10-30T23:58:00+08:00")))
            XCTAssertNil(model.moon.errorMessage)
            XCTAssertNil(model.tides.errorMessage)
        }
    }

    func testTideFailureDoesNotHideMoonTimesAndMoonFailureDoesNotHideTides() {
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            MoonTidesMockURLProtocol.handler = { request in
                if try Self.query(request)["dataType"] == "HLT" { throw URLError(.notConnectedToInternet) }
                return try Self.dailyResponse(request)
            }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNotNil(model.moon.value)
            XCTAssertNil(model.moon.errorMessage)
            XCTAssertNil(model.tides.value)
            XCTAssertNotNil(model.tides.errorMessage)

            MoonTidesMockURLProtocol.handler = { request in
                if try Self.query(request)["dataType"] == "MRS" { throw URLError(.timedOut) }
                return try Self.dailyResponse(request)
            }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNotNil(model.tides.value)
            XCTAssertNil(model.tides.errorMessage)
            XCTAssertNotNil(model.moon.value, "A failed refresh keeps the last successful moon times")
            XCTAssertNotNil(model.moon.errorMessage)
        }
    }

    func testChangingStationRequestsThatStationAndNeverShowsTheOldStationsTides() {
        let stations = RequestLog()
        MoonTidesMockURLProtocol.handler = { request in
            stations.append(try Self.query(request)["station"] ?? "-")
            return try Self.dailyResponse(request)
        }
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(model.tides.value?.today.readings.first?.heightMeters, 0.60)
            await model.refresh(lang: "en", station: Self.cheungChau)
            XCTAssertEqual(model.tides.value?.station.id, "CCH")
            XCTAssertEqual(model.tides.value?.today.readings.first?.heightMeters, 0.52)
            XCTAssertTrue(stations.values.contains("CCH"))

            MoonTidesMockURLProtocol.handler = { request in
                if try Self.query(request)["station"] == "WAG" { throw URLError(.timedOut) }
                return try Self.dailyResponse(request)
            }
            await model.refresh(lang: "en", station: TideStationCatalog.station(withID: "WAG")!)
            XCTAssertNil(model.tides.value, "Cheung Chau's tides must not stay visible under Waglan Island")
            XCTAssertNil(model.tides.lastChecked)
            XCTAssertNotNil(model.tides.errorMessage)
            XCTAssertNotNil(model.moon.value, "The moon times do not depend on the station")
        }
    }

    func testRefreshFailureRetainsTheSnapshotAndRecovers() {
        MoonTidesMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            let checked = model.tides.lastChecked
            MoonTidesMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNotNil(model.tides.value)
            XCTAssertEqual(model.tides.lastChecked, checked)
            XCTAssertNotNil(model.tides.errorMessage)
            XCTAssertNotNil(model.moon.errorMessage)
            XCTAssertFalse(model.isLoading)
            MoonTidesMockURLProtocol.handler = Self.dailyResponse
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNil(model.tides.errorMessage)
            XCTAssertNil(model.moon.errorMessage)
        }
    }

    func testLanguageChangeFailureClearsBothSections() {
        MoonTidesMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            MoonTidesMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
            await model.refresh(lang: "tc", station: TideStationCatalog.defaultStation)
            XCTAssertNil(model.moon.value)
            XCTAssertNil(model.tides.value)
            XCTAssertNil(model.moon.lastChecked)
            XCTAssertNotNil(model.moon.errorMessage)
            XCTAssertNotNil(model.tides.errorMessage)
        }
    }

    func testHongKongDateRolloverClearsOldTimesOnFailedRefresh() {
        MoonTidesMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let clock = ClockBox(Self.date("2026-10-30T23:59:00+08:00"))
            let model = MoonTidesViewModel(service: service, now: { clock.value })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            clock.value = Self.date("2026-10-31T00:00:00+08:00")
            MoonTidesMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNil(model.moon.value)
            XCTAssertNil(model.tides.value)
            XCTAssertNotNil(model.tides.errorMessage)
        }
    }

    func testYearBoundaryRequestsJanuaryFirstAsTomorrow() {
        MoonTidesMockURLProtocol.handler = Self.dailyResponse
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-12-31T22:00:00+08:00") })
            await model.refresh(lang: "tc", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(model.moon.value?.nextDay?.date, Self.date("2027-01-01T00:00:00+08:00"))
            XCTAssertEqual(model.tides.value?.nextDay?.date, Self.date("2027-01-01T00:00:00+08:00"))
            XCTAssertNil(model.tides.errorMessage)
        }
    }

    func testRequestCrossingMidnightReloadsTheNewHongKongDate() {
        let clock = ClockBox(Self.date("2026-10-30T23:59:59+08:00"))
        let flipped = RequestCounter()
        MoonTidesMockURLProtocol.handler = { request in
            // The clock passes midnight while the first request is in flight.
            if flipped.increment() == 1 { clock.value = Self.date("2026-10-31T00:00:01+08:00") }
            return try Self.dailyResponse(request)
        }
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { clock.value })
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertEqual(model.moon.value?.today.date, Self.date("2026-10-31T00:00:00+08:00"))
            XCTAssertEqual(model.moon.value?.tomorrow?.date, Self.date("2026-11-01T00:00:00+08:00"))
            XCTAssertEqual(model.tides.value?.today.date, Self.date("2026-10-31T00:00:00+08:00"))
            XCTAssertNil(model.moon.errorMessage)
            XCTAssertNil(model.tides.errorMessage)
            XCTAssertFalse(model.isLoading)
        }
    }

    func testInitialFailureAndCancellationDoNotCreateMoonOrTideData() {
        onMainActor { service in
            let model = MoonTidesViewModel(service: service, now: { Self.date("2026-10-30T12:00:00+08:00") })
            MoonTidesMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNil(model.moon.value)
            XCTAssertNil(model.tides.value)
            XCTAssertNil(model.moon.errorMessage)
            XCTAssertNil(model.tides.errorMessage)
            XCTAssertFalse(model.isLoading)
            MoonTidesMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
            await model.refresh(lang: "en", station: TideStationCatalog.defaultStation)
            XCTAssertNil(model.moon.value)
            XCTAssertNotNil(model.moon.errorMessage)
            XCTAssertNotNil(model.tides.errorMessage)
        }
    }

    // MARK: Helpers

    private static var cheungChau: TideStation { TideStationCatalog.station(withID: "CCH")! }

    private func decodeMoon(_ body: String) throws -> MoonTimesResponse {
        try JSONDecoder().decode(MoonTimesResponse.self, from: Data(body.utf8))
    }

    private func decodeTide(_ body: String) throws -> TideTimesResponse {
        try JSONDecoder().decode(TideTimesResponse.self, from: Data(body.utf8))
    }

    private func moonDay(_ date: String, rise: String, set: String) throws -> MoonDay {
        try XCTUnwrap(decodeMoon(Self.moonBody(day: date, rise: rise, set: set)).days.first)
    }

    private func moonSnapshot() throws -> MoonTimesSnapshot {
        MoonTimesSnapshot(today: try moonDay("2026-10-30", rise: "21:31", set: "10:40"),
                          tomorrow: try moonDay("2026-10-31", rise: "22:19", set: "11:32"))
    }

    private func tideDay(month: String = "10", day: String, cells: [String]) throws -> TideDay {
        let row = try XCTUnwrap(decodeTide(Self.tideBody(month: month, day: day, cells: cells)).rows.first)
        return try row.tideDay(year: 2026)
    }

    // Today is the real Quarry Bay row for 2026-10-30; tomorrow is synthetic.
    private func tideSnapshot() throws -> TideTimesSnapshot {
        TideTimesSnapshot(station: TideStationCatalog.defaultStation,
                          today: try tideDay(day: "30", cells: Self.quarryBayToday),
                          tomorrow: try tideDay(day: "31", cells: ["0658", "0.58", "1425", "1.60", "1650", "1.47"]))
    }

    private static let quarryBayToday = ["0616", "0.60", "1331", "1.64", "1602", "1.49", "2355", "2.64"]
    private static let cheungChauToday = ["0626", "0.52", "1340", "1.62", "1608", "1.49", "2323", "2.65"]

    private static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private static func moonBody(day: String = "2026-10-30", rise: String = "21:31", set: String = "10:40") -> String {
        "{\"fields\":[\"YYYY-MM-DD\",\"RISE\",\"TRAN.\",\"SET\"],\"data\":[[\"\(day)\",\"\(rise)\",\"03:33\",\"\(set)\"]]}"
    }

    /// HKO's HLT table: Month, Date and four Time/Height(m) pairs, with blank cells for missing tides.
    private static func tideBody(month: String = "10", day: String = "30", cells: [String]? = nil) -> String {
        let pairs = (cells ?? cheungChauToday)
        let padded = pairs + Array(repeating: "", count: max(0, 8 - pairs.count))
        let fields = ["Month", "Date"] + Array(repeating: ["Time", "Height(m)"], count: 4).flatMap { $0 }
        let row = [month, day] + padded
        func json(_ values: [String]) -> String { "[" + values.map { "\"\($0)\"" }.joined(separator: ",") + "]" }
        return "{\"fields\":\(json(fields)),\"data\":[\(json(row))]}"
    }

    private static func query(_ request: URLRequest) throws -> [String: String] {
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
    }

    /// Answers any MRS or HLT request for the date and station it names, like the live service.
    private static func dailyResponse(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let parts = try query(request)
        let (year, month, day) = (Int(parts["year"]!)!, Int(parts["month"]!)!, Int(parts["day"]!)!)
        switch parts["dataType"] {
        case "MRS":
            return try response(request, body: moonBody(day: String(format: "%04d-%02d-%02d", year, month, day)))
        case "HLT":
            let cells = parts["station"] == "QUB" ? quarryBayToday : cheungChauToday
            return try response(request, body: tideBody(month: String(format: "%02d", month),
                                                        day: String(format: "%02d", day), cells: cells))
        default:
            throw URLError(.badURL)
        }
    }

    private static func response(_ request: URLRequest, body: String, status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)), Data(body.utf8))
    }

    private func perform(_ operation: @escaping (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Moon and tide request completes")
        let client = service!
        Task {
            do { try await operation(client) } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }

    private func onMainActor(_ operation: @escaping @MainActor (WeatherService) async throws -> Void) {
        let finished = expectation(description: "Moon and tides operation completes")
        let client = service!
        Task { @MainActor in
            do { try await operation(client) } catch { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        wait(for: [finished], timeout: 5)
    }
}

private final class MoonTidesMemoryStorage: SettingsStorage {
    var values: [String: String] = [:]
    func read(_ key: String) -> String? { values[key] }
    func write(_ value: String, forKey key: String) { values[key] = value }
}

/// Handlers run on URLSession's threads, so shared test state is lock protected.
private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return total }
    @discardableResult
    func increment() -> Int { lock.lock(); defer { lock.unlock() }; total += 1; return total }
}

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    var values: [String] { lock.lock(); defer { lock.unlock() }; return stored }
    func append(_ value: String) { lock.lock(); defer { lock.unlock() }; stored.append(value) }
}

private final class ClockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Date
    init(_ date: Date) { stored = date }
    var value: Date {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}

private final class MoonTidesMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var storedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get { lock.lock(); defer { lock.unlock() }; return storedHandler }
        set { lock.lock(); defer { lock.unlock() }; storedHandler = newValue }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.1)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
