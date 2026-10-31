import Foundation

/// Decides whether a screen should refresh when the app returns from the background.
///
/// Only a screen the user can see refreshes. A screen covered by another one (Today under a pushed report)
/// reloads through its own `.task` when it reappears, so refreshing it too would repeat that request and
/// fetch data nobody is looking at: one foreground return with the explorer open made 9 requests, 8 of them
/// for the hidden Today screen, which then fetched them again when it reappeared.
struct ForegroundRefreshGate {
    /// Kept up to date from the screen's appear and disappear callbacks.
    var isVisible = false
    private var wasInBackground = false

    mutating func sceneEnteredBackground() { wasInBackground = true }

    /// True when the app has just returned from the background and this screen is visible. Becoming active
    /// without a background visit (Control Center, an incoming call) does not refresh.
    mutating func sceneBecameActive() -> Bool {
        defer { wasInBackground = false }
        return wasInBackground && isVisible
    }
}
