//
//  RegionWeatherInfoView.swift
//  WeatherApp
//
//  Created by Jeffrey Cheung on 30/4/2023.
//

import SwiftUI
import MapKit

struct RegionWeatherInfoView: View {
    @State var regionWeatherForecast = RegionWeatherForecast()
    @State var weatherType: String
    
    @ObservedObject var weatherViewModel: WeatherViewModel
    
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.500702, longitude: -0.124562), latitudinalMeters: 1000, longitudinalMeters: 1000)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, content: {
                Text("\(String(localized: "last_updated")): \(Utils().getCurrentDate(dateFormat: "yyyy-MM-dd HH:mm:ss"))")
                
                if regionWeatherForecast.rainfall?.data?.count ?? 0 > 0 {
                    Text(String(localized: "region_weather_rainfall_title"))
                        .padding([.top], 10)
                        .font(.title)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(regionWeatherForecast.rainfall?.data ?? [], id: \.place) { (data) in
                                let regionalWeatherDetail: RegionalWeatherDetail = RegionalWeatherDetail(topTitle: data.place ?? "", middleTitle: String(data.max ?? 0), bottomTitle: String(data.min ?? 0))
                                RegionalWeatherDetailView(regionalWeatherDetail: regionalWeatherDetail)
                            }
                        }
                    }
                }
                
                if regionWeatherForecast.rainfall?.data?.count ?? 0 > 0 {
                    Text(String(localized: "region_weather_temperature_title"))
                        .padding([.top], 10)
                        .font(.title)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(regionWeatherForecast.temperature?.data ?? [], id: \.place) { (data) in
                                let regionalWeatherDetail: RegionalWeatherDetail = RegionalWeatherDetail(topTitle: data.place ?? "", bottomTitle: "\(data.value ?? 0) \(data.unit ?? "")")
                                RegionalWeatherDetailView(regionalWeatherDetail: regionalWeatherDetail)
                            }
                        }
                    }
                }
                
                RegionMapView() 
            })
        }
        .padding([.leading, .trailing], 10)
        .onAppear(perform: {
            getRegionWeatherForecast()
        })
        .navigationTitle(String(localized: "region_weather_title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            getRegionWeatherForecast()
        }
    }
    
    func getRegionWeatherForecast() {
        var urlComponents = URLComponents(string: weatherViewModel.baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataType", value: DataType().currentWeatherReport),
            URLQueryItem(name: "lang", value: Utils().getApiLanguageCode())
        ]
        
        guard let urlComponents = urlComponents else {
            return
        }
        
        weatherViewModel.getRegionWeatherForecast(urlComponents: urlComponents, completed: {(result) in
            self.regionWeatherForecast = result
        })
    }
}

struct RegionWeatherInfoView_Previews: PreviewProvider {
    static var previews: some View {
        RegionWeatherInfoView(weatherType: DataType().currentWeatherReport, weatherViewModel: WeatherViewModel())
    }
}
