//
//  WeatherAppApp.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/8/2022.
//

import SwiftUI
import UIKit
import SwiftData

@main
@MainActor
struct WeatherAppApp: App {
    @StateObject private var settings = AppSettings()
    @State private var favoritesContainer: ModelContainer?
    @State private var favoritesUnavailable = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let favoritesContainer {
                    ContentView()
                        .modelContainer(favoritesContainer)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if favoritesUnavailable { favoritesBanner }
                        }
                } else {
                    ProgressView(settings.text("favorites_loading"))
                }
            }
            .environmentObject(settings)
            .environment(\.locale, settings.locale)
            // Set on the windows (not with preferredColorScheme): a presented sheet keeps a
            // forced scheme after preferredColorScheme(nil), so Follow device would not restore it.
            .onChange(of: settings.appearance, initial: true) { _, appearance in
                appearance.apply()
            }
            .task {
                if favoritesContainer == nil { loadFavorites() }
            }
        }
    }

    private var favoritesBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.badge.exclamationmark")
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.text("favorites_storage_error_title")).font(.footnote.bold())
                Text(settings.text("favorites_storage_unavailable_note")).font(.caption)
            }
            Spacer(minLength: 0)
            Button(settings.text("weather_retry"), action: loadFavorites).font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    // The existing store is never reset. If it cannot open, weather browsing
    // continues with a temporary in-memory favorites store until a retry succeeds.
    private func loadFavorites() {
        do {
            // UI tests pass this flag so they never touch the user's saved favorites.
            let inMemory = ProcessInfo.processInfo.arguments.contains("-uitest-in-memory-favorites")
            favoritesContainer = try FavoritesPersistence.makeContainer(inMemory: inMemory)
            favoritesUnavailable = false
        } catch {
            if favoritesContainer == nil || !favoritesUnavailable {
                favoritesContainer = try? FavoritesPersistence.makeContainer(inMemory: true)
            }
            favoritesUnavailable = true
        }
    }
}

extension AppAppearance {
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Applies the choice to every window, which also covers sheets presented from them.
    @MainActor
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}
