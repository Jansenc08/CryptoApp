//
//  CustomFormatters.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 8/7/25.
//
//  This file contains custom formatters for DGCharts to properly display
//  cryptocurrency prices and dates in both line and candlestick charts.

import Foundation
import DGCharts

// MARK: - Price Formatter for Chart Y-Axis

/**
 * PriceFormatter handles the Y-axis price labels for cryptocurrency charts.
 * 
 * Key features:
 * - Automatically abbreviates large numbers (K for thousands, M for millions)
 * - Adjusts decimal precision based on price magnitude
 * - Maintains consistent USD currency formatting
 * - Optimized for chart readability with minimal space usage
 */
class PriceFormatter: AxisValueFormatter {
    
    /// Pre-configured NumberFormatter for consistent currency formatting
    private let formatter: NumberFormatter
    
    init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US")
    }
    
    /**
     * Formats price values for Y-axis display with intelligent abbreviation
     * 
     * Formatting tiers:
     * - $1M+ → "$1.5M" (1 decimal place)
     * - $1K+ → "$1.2K" (1 decimal place)  
     * - $1+ → "$45" (no decimals for whole dollars)
     * - <$1 → "$0.0045" (4 decimals for precision on low-value coins)
     */
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        // Format large numbers with abbreviations for chart space efficiency
        if value >= 1000000 {
            return String(format: "$%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "$%.1fK", value / 1000)
        } else if value >= 1 {
            return String(format: "$%.0f", value)
        } else {
            // Show more precision for low-value cryptocurrencies (e.g., altcoins)
            return String(format: "$%.4f", value)
        }
    }
}

// MARK: - Date Formatter for Chart X-Axis

/**
 * DateValueFormatter handles the X-axis time/date labels for cryptocurrency charts.
 * 
 * Adaptive formatting based on time range:
 * - 24h range: Shows time of day (9 AM, 12 PM, 6 PM) for intraday analysis
 * - Other ranges: Shows date format (07/22, 07/23) for multi-day periods
 * 
 * This provides optimal readability for different trading timeframes.
 */
class DateValueFormatter: AxisValueFormatter {
    
    /// Cache of date objects for efficient lookups (used by some chart implementations)
    private var dates: [Date] = []
    
    /// DateFormatter instance configured based on current time range
    private let dateFormatter = DateFormatter()
    
    /// Current time range filter (24h, 7d, 30d, All) that determines formatting style
    private var currentRange: String = "24h"
    
    init() {
        // Ensure formatter uses local timezone (important for users outside UTC)
        dateFormatter.timeZone = TimeZone.current
        updateFormat()
    }
    
    /**
     * Updates the internal date cache for efficient date lookups
     * - Parameter newDates: Array of Date objects corresponding to chart data points
     */
    func updateDates(_ newDates: [Date]) {
        self.dates = newDates
    }
    
    /**
     * Updates the current time range and automatically adjusts date formatting
     * - Parameter range: Time range string ("24h", "7d", "30d", "All")
     */
    func updateRange(_ range: String) {
        self.currentRange = range
        updateFormat()
    }
    
    /**
     * Configures the DateFormatter based on the current time range for optimal readability
     * 
     * Format strategy:
     * - 24h: Time-focused format (h a) → "9 AM", "12 PM", "6 PM"
     * - Other: Date-focused format (MM/dd) → "07/22", "07/23"
     */
    private func updateFormat() {
        // For 24h filter, show time of day instead of date for intraday analysis
        if currentRange == "24h" {
            dateFormatter.dateFormat = "h a"  // "9 AM", "12 PM", "6 PM"
        } else {
            // For longer periods, show date for trend analysis over days/weeks/months
            dateFormatter.dateFormat = "MM/dd"  // "07/22", "07/23"
        }
    }
    
    /**
     * Converts timestamp values to formatted date/time strings for X-axis display
     * - Parameter value: Unix timestamp as Double (seconds since 1970)
     * - Parameter axis: AxisBase reference (unused but required by protocol)
     * - Returns: Formatted date/time string based on current range settings
     */
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        // Convert Unix timestamp to Date object and format according to current range
        let date = Date(timeIntervalSince1970: value)
        return dateFormatter.string(from: date)
    }
}
