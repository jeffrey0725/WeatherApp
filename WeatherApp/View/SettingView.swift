//
//  SettingView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 30/8/2022.
//

import SwiftUI

struct SettingView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                Picker(settings.text("settings_language"), selection: $settings.language) {
                    Text(settings.text("settings_follow_system")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("繁體中文").tag(AppLanguage.traditionalChinese)
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text(settings.text("settings_language_help"))
            }

            Section {
                Picker(settings.text("settings_temperature_unit"), selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(settings.text("settings_temperature_unit"))
            } header: {
                Text(settings.text("settings_temperature_unit"))
            } footer: {
                Text(settings.text("settings_temperature_help"))
            }
        }
        .navigationTitle(settings.text("settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(settings.text("settings_done")) { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingView()
    }
    .environmentObject(AppSettings.preview)
}
