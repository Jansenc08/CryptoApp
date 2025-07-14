//
//  StatItem.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

import UIKit

// Represents a single statistic (e.g., market cap or volume) with a title and a value.
// Used in Stats section to display data
struct StatItem {
    let title: String
    let value: String
    let valueColor: UIColor? // New property to specify text color
    
    init(title: String, value: String, valueColor: UIColor? = nil) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
}
