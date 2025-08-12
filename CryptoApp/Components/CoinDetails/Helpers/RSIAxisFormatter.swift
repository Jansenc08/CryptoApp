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
            // Return empty string to hide RSI y-axis values
            return ""
        } else if value >= priceStart {
            // For price section, use price formatting
            return PriceFormatter().stringForValue(value, axis: axis)
        } else {
            // Hide labels in gap between sections
            return ""
        }
    }
}