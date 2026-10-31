import XCTest
#if !HKO_STANDALONE_TESTS
@testable import WeatherApp
#endif

final class ForegroundRefreshGateTests: XCTestCase {
    func testVisibleScreenRefreshesOnceAfterAReturnFromTheBackground() {
        var gate = ForegroundRefreshGate()
        gate.isVisible = true
        gate.sceneEnteredBackground()
        XCTAssertTrue(gate.sceneBecameActive())
        XCTAssertFalse(gate.sceneBecameActive(), "One background visit refreshes once")
    }

    func testCoveredScreenDoesNotRefreshBecauseItReloadsWhenItReappears() {
        var gate = ForegroundRefreshGate()
        gate.isVisible = false
        gate.sceneEnteredBackground()
        XCTAssertFalse(gate.sceneBecameActive(), "Today under a pushed report must not fetch hidden data")
    }

    func testBecomingActiveWithoutABackgroundVisitDoesNotRefresh() {
        var gate = ForegroundRefreshGate()
        gate.isVisible = true
        XCTAssertFalse(gate.sceneBecameActive(), "Control Center or a call only makes the scene inactive")
    }

    func testVisibilityAtReturnDecidesNotVisibilityAtBackgrounding() {
        var gate = ForegroundRefreshGate()
        gate.isVisible = true
        gate.sceneEnteredBackground()
        gate.isVisible = false
        XCTAssertFalse(gate.sceneBecameActive())

        gate.isVisible = false
        gate.sceneEnteredBackground()
        gate.isVisible = true
        XCTAssertTrue(gate.sceneBecameActive())
    }

    func testAHiddenReturnIsNotRememberedForLater() {
        // The screen catches up through its own reload when it reappears, not through the gate.
        var gate = ForegroundRefreshGate()
        gate.isVisible = false
        gate.sceneEnteredBackground()
        XCTAssertFalse(gate.sceneBecameActive())
        gate.isVisible = true
        XCTAssertFalse(gate.sceneBecameActive())
    }

    func testRepeatedBackgroundVisitsEachRefreshAVisibleScreen() {
        var gate = ForegroundRefreshGate()
        gate.isVisible = true
        for _ in 0..<3 {
            gate.sceneEnteredBackground()
            XCTAssertTrue(gate.sceneBecameActive())
        }
    }
}
