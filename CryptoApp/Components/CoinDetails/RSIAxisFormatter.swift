//
//  RSIAxisFormatter.swift
//  CryptoApp
//
//  Custom axis formatter for separate RSI section
//

import Foundation
import DGCharts

class RSISeparateAxisFormatter: NSObject, AxisValueFormatter {
    private let rsiStart: Double
    private let rsiEnd: Double
    private let priceStart: Double
    
    init(rsiStart: Double, rsiEnd: Double, priceStart: Double) {
        self.rsiStart = rsiStart
        self.rsiEnd = rsiEnd
        self.priceStart = priceStart
        super.init()
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        // Check if value is in RSI section
        if value >= rsiStart && value <= rsiEnd {
            // Convert coordinate back to RSI value (0-100)
            let rsiValue = ((value - rsiStart) / (rsiEnd - rsiStart)) * 100.0
            let roundedRSI = Int(round(rsiValue))
            
            // Show key RSI levels: 0, 30, 50, 70, 100
            switch roundedRSI {
            case 0...5: return "0"
            case 25...35: return "30"
            case 45...55: return "50"
            case 65...75: return "70" 
            case 95...100: return "100"
            default: return ""
            }
        } else if value >= priceStart {
            // For price section, use price formatting
            return PriceFormatter().stringForValue(value, axis: axis)
        } else {
            // Hide labels in gap between sections
            return ""
        }
    }
}