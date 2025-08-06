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
            
            let timestampValue = item[0]
            let open = item[1]
            let high = item[2]
            let low = item[3]
            let close = item[4]
            
            // VALIDATE: Ensure all OHLC values are finite and valid
            guard timestampValue.isFinite && timestampValue > 0,
                  open.isFinite && open >= 0,
                  high.isFinite && high >= 0,
                  low.isFinite && low >= 0,
                  close.isFinite && close >= 0 else {
                return nil
            }
            
            // VALIDATE: Ensure OHLC relationships are logical
            guard high >= low,
                  high >= open,
                  high >= close,
                  low <= open,
                  low <= close else {
                return nil
            }
            
            let timestamp = Date(timeIntervalSince1970: timestampValue / 1000) // Convert from milliseconds
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
