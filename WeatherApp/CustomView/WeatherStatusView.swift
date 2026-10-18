import SwiftUI

extension View {
    func refreshWeatherOnActivation(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(WeatherActivationRefresh(action: action))
    }
}

private struct WeatherActivationRefresh: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var needsRefresh = false
    let action: @MainActor () async -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            if phase == .background { needsRefresh = true }
            if phase == .active && needsRefresh {
                needsRefresh = false
                Task { await action() }
            }
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
