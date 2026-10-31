import SwiftUI

extension View {
    func refreshWeatherOnActivation(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(WeatherActivationRefresh(action: action))
    }
}

// Every screen that uses this also reloads in `.task(id:)` when it appears, so a covered screen skips the
// foreground refresh (see ForegroundRefreshGate) and catches up when the user returns to it.
private struct WeatherActivationRefresh: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var gate = ForegroundRefreshGate()
    let action: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content
            .onAppear { gate.isVisible = true }
            .onDisappear { gate.isVisible = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { gate.sceneEnteredBackground() }
                if phase == .active && gate.sceneBecameActive() { Task { await action() } }
            }
    }
}

/// Refresh toolbar label with both a title and a symbol, so the system can show it as an icon (the
/// iPhone Duo's side toolbar), an icon or a title, or both in an overflow menu. While loading the symbol
/// pulses instead of being swapped for a ProgressView, because a custom view is not shown in the side toolbar.
struct RefreshToolbarLabel: View {
    @EnvironmentObject private var settings: AppSettings
    let isLoading: Bool

    var body: some View {
        Label {
            Text(settings.text("weather_refresh"))
        } icon: {
            Image(systemName: "arrow.clockwise").symbolEffect(.pulse, isActive: isLoading)
        }
    }
}

extension ToolbarContent {
    /// Keeps frequently used items visible longest when the iPhone Duo's side toolbar runs out of room
    /// (visibility priority exists from iOS 27; earlier systems ignore it).
    @ToolbarContentBuilder
    func keepVisibleLongest() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            self.visibilityPriority(.high)
        } else {
            self
        }
    }
}

struct WeatherStatusView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var viewModel: WeatherViewModel
    let retry: () -> Void

    var body: some View {
        if viewModel.isLoading {
            ProgressView(settings.text("weather_loading"))
                .frame(maxWidth: .infinity)
                .padding()
        }
        if let error = viewModel.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label(error, systemImage: "exclamationmark.triangle")
                Button(settings.text("weather_retry"), action: retry)
                    .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct WeatherUpdateView: View {
    @EnvironmentObject private var settings: AppSettings
    let timestamp: String?

    var body: some View {
        if let time = settings.timestamp(timestamp) {
            Text("\(settings.text("last_updated")): \(time)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct WeatherIconView: View {
    let icon: Int

    var body: some View {
        AsyncImage(url: URL(string: "https://www.hko.gov.hk/images/HKOWxIconOutline/pic\(icon).png")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "cloud.fill").foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(width: 50, height: 50)
        .accessibilityHidden(true)
    }
}
