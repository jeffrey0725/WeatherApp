//
//  WeatherAppApp.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 8/8/2022.
//

import SwiftUI
import SwiftData

@main
@MainActor
struct WeatherAppApp: App {
    @StateObject private var settings = AppSettings()
    @State private var favoritesContainer: ModelContainer?
    @State private var storageFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let favoritesContainer {
                    ContentView().modelContainer(favoritesContainer)
                } else if storageFailed {
                    ContentUnavailableView {
                        Label(settings.text("favorites_storage_error_title"), systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(settings.text("favorites_storage_error_message"))
                    } actions: {
                        Button(settings.text("weather_retry"), action: loadFavorites)
                    }
                } else {
                    ProgressView(settings.text("favorites_loading"))
                }
            }
            .environmentObject(settings)
            .environment(\.locale, settings.locale)
            .task {
                if favoritesContainer == nil && !storageFailed { loadFavorites() }
            }
        }
    }

    private func loadFavorites() {
        do {
            favoritesContainer = try FavoritesPersistence.makeContainer()
            storageFailed = false
        } catch {
            storageFailed = true
        }
    }
}
