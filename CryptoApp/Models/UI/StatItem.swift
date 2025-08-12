//
//  StatItem.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

import UIKit

// Strongly-typed payload for the Low/High stat to avoid string parsing in UI
struct HighLowPayload {
    let low: Double?
    let high: Double?
    let current: Double?
    let isLoading: Bool
}

// Represents a single statistic (e.g., market cap or volume) with a title and a value.
// Used in Stats section to display data
struct StatItem {
    let title: String
    let value: String
    let valueColor: UIColor? // New property to specify text color
    let highLowPayload: HighLowPayload?
    
    init(title: String, value: String, valueColor: UIColor? = nil) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.highLowPayload = nil
    }
    
    init(title: String, value: String, valueColor: UIColor? = nil, highLowPayload: HighLowPayload?) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.highLowPayload = highLowPayload
    }
}
