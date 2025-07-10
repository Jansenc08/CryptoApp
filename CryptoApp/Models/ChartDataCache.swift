//
//  ChartDataCache.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

// Temporarily stores fetched chart data and a timestamp.
struct ChartDataCache {
    let data: [Double] // An array of Double chart values
    let timestamp: Date // Time data was cached
    
    init(data: [Double]) {
        self.data = data
        self.timestamp = Date()
    }
    
    func isExpired() -> Bool {
        return Date().timeIntervalSince(timestamp) > 300 // Returns true if cahce is older than 5 mins (300 seconds)
    }
}
