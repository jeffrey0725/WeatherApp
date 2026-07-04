//
//  RollingBannerView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 3/7/2026.
//

import SwiftUI

struct RollingBannerView: View {
    let content: [String]
    let timerInterval: TimeInterval = 3.0
    
    @State private var scrollPosition: Int? = 0
    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()
    
    @State private var activeBanner: BannerItem? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(Color.orange)
                .font(.system(size: 16, weight: .bold))
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<content.count, id: \.self) { index in
                        Text(content[index])
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .containerRelativeFrame(.vertical)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeBanner = BannerItem(text: content[index])
                            }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .frame(height: 40)
            .scrollDisabled(true)
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.gray)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .onReceive(timer, perform: { _ in
            guard activeBanner == nil else { return }
            guard !content.isEmpty else { return }
            
            withAnimation(.easeInOut(duration: 0.6)) {
                let currentIndex = scrollPosition ?? 0
                if currentIndex == content.count - 1 {
                    scrollPosition = 0
                } else {
                    scrollPosition = currentIndex + 1
                }
            }
        })
        .sheet(item: $activeBanner) { item in
            BannerDetailView(text: item.text)
        }
    }
}

#Preview {
    RollingBannerView(content: [])
}
