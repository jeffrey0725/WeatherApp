//
//  BannerDetailView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 3/7/2026.
//

import SwiftUI

struct BannerDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    let text: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text(settings.text("weather_read_details"))
                        .font(.headline)
                }
                .padding(.top)
                
                Divider()
                
                ScrollView {
                    Text(text)
                        .font(.body)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle(settings.text("weather_information"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(settings.text("weather_close")) {
                        dismiss()
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    BannerDetailView(text: "")
        .environmentObject(AppSettings.preview)
}
