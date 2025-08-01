//
//  OHLCData.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import Foundation

// MARK: - OHLC Data Model for Candlestick Charts
struct OHLCData {
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    
    init(timestamp: Date, open: Double, high: Double, low: Double, close: Double, volume: Double? = nil) {
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
    
    // Helper computed properties
    var isBullish: Bool {
        return close >= open
    }
    
    var bodySize: Double {
        return abs(close - open)
    }
    
    var wickRange: Double {
        return high - low
    }
    
    var upperWickLength: Double {
        return high - max(open, close)
    }
    
    var lowerWickLength: Double {
        return min(open, close) - low
    }
}

// MARK: - CoinGecko OHLC Response Extension
// DATA CONVERSION: CoinGecko response → OHLCData objects
extension Array where Element == [Double] {
    func toOHLCData() -> [OHLCData] {
        return self.compactMap { item in
            guard item.count >= 5 else { return nil }
            
            let timestamp = Date(timeIntervalSince1970: item[0] / 1000) // Convert from milliseconds
            let open = item[1]
            let high = item[2]
            let low = item[3]
            let close = item[4]
            
            return OHLCData(timestamp: timestamp, open: open, high: high, low: low, close: close)
        }
    }
}

// MARK: - Chart Type Enum
enum ChartType: String, CaseIterable {
    case line = "Line"
    case candlestick = "Candle"
    
    var systemImageName: String {
        switch self {
        case .line:
            return "chart.line.uptrend.xyaxis"
        case .candlestick:
            return "chart.bar.fill"
        }
    }
} 
