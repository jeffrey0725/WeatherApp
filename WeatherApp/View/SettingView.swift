//
//  SettingView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 30/8/2022.
//

import SwiftUI

struct SettingView: View {
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        List {
            
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarLeading, content: {
                Button(action: {
                    print("--------BACK PRESSED--------")
                    self.presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "arrow.backward")
                })
                    .buttonStyle(.plain)
            })
        })
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView()
    }
}
