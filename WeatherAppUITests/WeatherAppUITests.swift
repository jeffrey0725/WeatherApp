import XCTest

/// Simulator checks for the main user flows. They run against the live HKO feeds,
/// so they assert on structure (headings, controls, sheets) rather than weather values.
/// Favorites use an in-memory store and the language/unit preferences are forced by
/// launch arguments, so the tests never read or change the user's saved data.
class WeatherUITestCase: XCTestCase {
    let networkTimeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launchApp(language: String = "en", unit: String = "celsius", appearance: String = "system") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language == "en" ? "en" : "zh-Hant"))",
                                "-weather.settings.language", language,
                                "-weather.settings.temperatureUnit", unit,
                                "-weather.settings.appearance", appearance,
                                "-uitest-in-memory-favorites"]
        app.launch()
        return app
    }

    func openWeatherLink(_ app: XCUIApplication, _ title: String) {
        let link = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        if !link.waitForExistence(timeout: 10) || !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.waitForExistence(timeout: 10), "Missing link: \(title)")
        link.tap()
    }

    /// Average brightness (0...1) of the sampled screenshot, used to tell light from dark appearance.
    func brightness(of app: XCUIApplication) -> Double {
        guard let cg = app.screenshot().image.cgImage else { return -1 }
        let width = 32, height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var total = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            total += (0.299 * Double(pixels[i]) + 0.587 * Double(pixels[i + 1]) + 0.114 * Double(pixels[i + 2])) / 255
        }
        return total / Double(width * height)
    }

    /// iOS 27 moves navigation controls into a side toolbar on the iPhone Duo's open display,
    /// where the back button is no longer inside the navigation bar.
    func goBack(_ app: XCUIApplication) {
        let sideButton = app.buttons["BackButton"]
        if sideButton.exists { sideButton.tap(); return }
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Some simulators (the iPhone Duo on a headless Mac) return all-black screenshots, which
    /// makes brightness checks meaningless, so those tests skip instead of failing.
    func requireReadableScreenshots(_ app: XCUIApplication) throws {
        try XCTSkipIf(brightness(of: app) < 0.001, "This simulator renders blank screenshots")
    }

    /// The Map/List picker only exists on narrow windows; wide windows show both at once.
    func selectDisplay(_ app: XCUIApplication, _ title: String) {
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 3) { button.tap() }
    }

    func firstStationRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "°C")).firstMatch
    }
}

final class DashboardUITests: WeatherUITestCase {
    func testLaunchShowsTodayDashboard() throws {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Refresh weather"].exists || app.activityIndicators.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
    }

    func testPullToRefreshReturnsToOriginalScrollPosition() throws {
        let app = launchApp()
        let heading = app.staticTexts["Hong Kong"]
        XCTAssertTrue(heading.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        let before = heading.frame.minY
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
        sleep(5)
        XCTAssertEqual(heading.frame.minY, before, accuracy: 2, "Scroll position should return after refresh")
    }
}

final class SettingsUITests: WeatherUITestCase {
    func testSettingsSheetOpensAndDone() throws {
        let app = launchApp()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
    }

    func testTemperatureUnitChangesDashboard() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        let celsius = NSPredicate(format: "label CONTAINS %@", "°C")
        XCTAssertTrue(app.staticTexts.containing(celsius).firstMatch.waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        app.buttons["°F"].tap()
        app.buttons["Done"].tap()
        let fahrenheit = NSPredicate(format: "label CONTAINS %@", "°F")
        XCTAssertTrue(app.staticTexts.containing(fahrenheit).firstMatch.waitForExistence(timeout: 10))
    }

    func testLanguageChangeSwitchesToTraditionalChinese() throws {
        let app = launchApp()
        app.buttons["Settings"].tap()
        app.buttons["Language"].tap()
        app.buttons["繁體中文"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        goBack(app) // Back from the picker, if shown.
        if app.buttons["完成"].waitForExistence(timeout: 3) { app.buttons["完成"].tap() }
        XCTAssertTrue(app.navigationBars["今日天氣"].waitForExistence(timeout: 10))
    }
}

final class FavoritesUITests: WeatherUITestCase {
    func testAddAndRemoveFavoriteFromManagementScreen() throws {
        let app = launchApp()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
        openWeatherLink(app, "Choose a station")
        XCTAssertTrue(app.navigationBars["Favorite stations"].waitForExistence(timeout: 5))
        app.buttons["Add favorite station"].firstMatch.tap()

        let station = app.buttons["King's Park"]
        XCTAssertTrue(station.waitForExistence(timeout: 5))
        station.tap()
        app.buttons["Save"].tap()

        let saved = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "King's Park")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "Saved station should be listed")

        saved.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Your weather, nearby"].waitForExistence(timeout: 5))
    }
}

final class RegionalExplorerUITests: WeatherUITestCase {
    func testListSelectionSheetAndFavoriteToggle() throws {
        let app = launchApp()
        openWeatherLink(app, "Weather around Hong Kong")
        XCTAssertTrue(app.navigationBars["Regional weather"].waitForExistence(timeout: 10))

        selectDisplay(app, "List")
        let row = firstStationRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: networkTimeout), "Station rows should load")
        row.tap()

        let save = app.buttons["Save to favorites"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Station sheet should open")
        save.tap()
        let remove = app.buttons["Remove from favorites"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        // Removing the only favorite must not dismiss the open sheet.
        remove.tap()
        XCTAssertTrue(app.buttons["Save to favorites"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Regional weather"].waitForExistence(timeout: 5))
    }

    func testOpeningExplorerDoesNotRequestLocationPermission() throws {
        let app = launchApp()
        openWeatherLink(app, "Weather around Hong Kong")
        XCTAssertTrue(app.buttons["Find nearby station"].waitForExistence(timeout: 10))
        sleep(3)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertEqual(springboard.alerts.count, 0, "No permission prompt before the user taps Find nearby station")
    }
}

final class RainfallUITests: WeatherUITestCase {
    func testMapListSwitchingAndStationSheet() throws {
        let app = launchApp()
        openWeatherLink(app, "Past-hour rainfall")
        XCTAssertTrue(app.navigationBars["Past-hour rainfall"].waitForExistence(timeout: 10))
        let matching = NSPredicate(format: "label BEGINSWITH %@", "Matching stations")
        XCTAssertTrue(app.staticTexts.containing(matching).firstMatch.waitForExistence(timeout: networkTimeout))

        selectDisplay(app, "Map")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Tap a station")).firstMatch
            .waitForExistence(timeout: 5), "Map mode should show its help text")
        selectDisplay(app, "List")
        XCTAssertTrue(app.staticTexts["Station ranking"].waitForExistence(timeout: 5))

        let rows = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "mm"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "Ranked rainfall rows should be listed")
        rows.firstMatch.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 10), "Rainfall station sheet should open")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.navigationBars["Past-hour rainfall"].waitForExistence(timeout: 5))
    }
}

final class AppearanceUITests: WeatherUITestCase {
    func testForcedDarkAndLightAppearancesOverrideTheSystem() throws {
        let dark = launchApp(appearance: "dark")
        XCTAssertTrue(dark.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        try requireReadableScreenshots(dark)
        XCTAssertLessThan(brightness(of: dark), 0.35, "Dark appearance should render a dark screen")
        dark.terminate()

        let light = launchApp(appearance: "light")
        XCTAssertTrue(light.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        XCTAssertGreaterThan(brightness(of: light), 0.6, "Light appearance should render a light screen")
    }

    func testSwitchingAppearanceInSettingsUpdatesTheAppAndSheet() throws {
        let app = launchApp(appearance: "light")
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
        try requireReadableScreenshots(app)
        XCTAssertGreaterThan(brightness(of: app), 0.6)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Dark"].tap()
        sleep(1)
        XCTAssertLessThan(brightness(of: app), 0.35, "The open Settings sheet should switch immediately")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertLessThan(brightness(of: app), 0.35)
    }

    /// Follow device must match whatever the simulator's system appearance is
    /// (run once under `simctl ui <udid> appearance light` and once under `dark`).
    func testFollowDeviceMatchesSystemAppearance() throws {
        let app = launchApp(appearance: "system")
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        try requireReadableScreenshots(app)
        let systemIsDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        let value = brightness(of: app)
        if systemIsDark { XCTAssertLessThan(value, 0.35, "Follow device should be dark under a dark system") }
        else { XCTAssertGreaterThan(value, 0.6, "Follow device should be light under a light system") }
    }

    /// Returning to Follow device from a forced appearance must also restore the open sheet.
    func testSwitchingBackToFollowDeviceRestoresSystemAppearanceInSheet() throws {
        let systemIsDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        let app = launchApp(appearance: systemIsDark ? "light" : "dark") // Opposite of the system.
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 15))
        try requireReadableScreenshots(app)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Follow device"].tap()
        sleep(1)
        let sheet = brightness(of: app)
        if systemIsDark { XCTAssertLessThan(sheet, 0.35) }
        else { XCTAssertGreaterThan(sheet, 0.6, "Sheet should follow the light system setting") }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        let page = brightness(of: app)
        if systemIsDark { XCTAssertLessThan(page, 0.35) }
        else { XCTAssertGreaterThan(page, 0.6) }
    }
}

/// Layout checks that depend on the window's width, not on a device name, so they hold for
/// iPhone, iPad, Split View and the iPhone Duo (open or folded).
final class AdaptiveLayoutUITests: WeatherUITestCase {
    private func windowWidth(_ app: XCUIApplication) -> CGFloat { app.windows.firstMatch.frame.width }

    private func assertNoHorizontalOverflow(_ app: XCUIApplication, _ screen: String,
                                            file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        var offenders: [String] = []
        for text in app.staticTexts.allElementsBoundByIndex where text.exists && text.frame.width > 0 {
            let frame = text.frame
            if frame.minX < window.minX - 1 || frame.maxX > window.maxX + 1 {
                offenders.append("\(text.label) \(frame)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "\(screen): text outside the \(window.width)pt window: \(offenders.prefix(3))",
                      file: file, line: line)
    }

    func testMainScreensStayWithinTheWindowWidth() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        assertNoHorizontalOverflow(app, "Today")

        openWeatherLink(app, "Weather around Hong Kong")
        XCTAssertTrue(app.navigationBars["Regional weather"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Stations shown"))
            .firstMatch.waitForExistence(timeout: networkTimeout))
        assertNoHorizontalOverflow(app, "Regional weather")
        goBack(app)

        openWeatherLink(app, "Past-hour rainfall")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Matching stations"))
            .firstMatch.waitForExistence(timeout: networkTimeout))
        assertNoHorizontalOverflow(app, "Rainfall")
    }

    /// The side-by-side layout is chosen by the horizontal size class plus the content width, so the
    /// test reads the layout the app reports and checks that the controls agree with it.
    func testMapAndListFollowTheReportedLayout() throws {
        let app = launchApp()
        let width = windowWidth(app)
        XCTAssertTrue(app.staticTexts["Current weather"].waitForExistence(timeout: networkTimeout))
        let todayWide = app.otherElements["layout.sideBySide"].exists
        let todaySingle = app.otherElements["layout.single"].exists
        XCTAssertTrue(todayWide != todaySingle, "Today should report exactly one layout")

        openWeatherLink(app, "Weather around Hong Kong")
        XCTAssertTrue(app.navigationBars["Regional weather"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Stations shown"))
            .firstMatch.waitForExistence(timeout: networkTimeout))
        let wide = app.otherElements["layout.sideBySide"].waitForExistence(timeout: 5)
        let single = app.otherElements["layout.single"].exists
        XCTAssertTrue(wide != single, "The explorer should report exactly one layout")
        add(XCTAttachment(string: "window \(width)pt, explorer layout: \(wide ? "sideBySide" : "single")"))

        if wide {
            XCTAssertFalse(app.buttons["List"].exists, "Side by side needs no Map/List picker")
            XCTAssertTrue(firstStationRow(app).waitForExistence(timeout: 10), "The list should sit beside the map")
        } else {
            XCTAssertTrue(app.buttons["List"].waitForExistence(timeout: 5), "A single column keeps the Map/List picker")
        }
        if width >= 900 { XCTAssertTrue(wide, "A \(width)pt window should be side by side") }
        if width <= 500 { XCTAssertTrue(single, "A \(width)pt window should be a single column") }
    }
}
