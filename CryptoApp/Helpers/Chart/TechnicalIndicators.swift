//
//  TechnicalIndicators.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
//

import Foundation
import UIKit

/**
 * Technical Indicator Calculation Engine
 *
 * This class provides comprehensive technical analysis calculations for cryptocurrency trading charts.
 * It includes moving averages, momentum oscillators, and volume analysis with robust error handling.
 *
 * Key Features:
 * - Simple Moving Average (SMA) and Exponential Moving Average (EMA)
 * - Relative Strength Index (RSI) with configurable overbought/oversold levels
 * - Volume analysis with ratio calculations
 * - Persistent settings storage via UserDefaults
 * - Theme-aware color management for chart indicators
 * - Comprehensive input validation and NaN protection
 *
 * Usage:
 * ```swift
 * let smaResult = TechnicalIndicators.calculateSMA(prices: closingPrices, period: 20)
 * let rsiResult = TechnicalIndicators.calculateRSI(prices: closingPrices, period: 14)
 * ```
 */
final class TechnicalIndicators {
    
    // MARK: - Indicator Configuration
    
    /**
     * Configuration structure for technical indicator display and calculation parameters.
     *
     * This struct defines which indicators should be shown on charts and their respective
     * calculation parameters. Settings are persisted across app sessions via UserDefaults.
     */
    struct IndicatorSettings {
        // MARK: Moving Averages
        /// Whether to display Simple Moving Average overlay on charts
        var showSMA: Bool = false
        /// Period for SMA calculation (typical range: 5-200, default: 20)
        var smaPeriod: Int = 20
        
        /// Whether to display Exponential Moving Average overlay on charts
        var showEMA: Bool = false
        /// Period for EMA calculation (typical range: 5-200, default: 12)
        var emaPeriod: Int = 12
        
        // MARK: RSI Configuration
        /// Whether to display RSI (Relative Strength Index) indicator
        var showRSI: Bool = false
        /// Period for RSI calculation (typical range: 14-21, default: 14)
        var rsiPeriod: Int = 14
        /// RSI level considered overbought (typical: 70-80, default: 70)
        var rsiOverbought: Double = 70
        /// RSI level considered oversold (typical: 20-30, default: 30)
        var rsiOversold: Double = 30
        
        // MARK: Volume Settings
        /// Whether to display volume bars (enabled by default for better market analysis)
        var showVolume: Bool = true
    }
    
    // MARK: - Indicator Results
    
    /**
     * Result structure for moving average calculations (SMA and EMA).
     *
     * Contains the calculated values along with metadata about the calculation parameters.
     * Values are optional to handle cases where calculation isn't possible (insufficient data, NaN, etc.).
     */
    struct MovingAverageResult {
        /// Array of calculated moving average values (nil for periods with insufficient data)
        let values: [Double?]
        /// The period used for calculation
        let period: Int
        /// Type of moving average calculated
        let type: MovingAverageType
        
        /// Enumeration of supported moving average types
        enum MovingAverageType {
            case simple      // Simple Moving Average (SMA)
            case exponential // Exponential Moving Average (EMA)
        }
    }
    
    /**
     * Result structure for RSI (Relative Strength Index) calculations.
     *
     * RSI is a momentum oscillator that measures the speed and magnitude of price changes.
     * Values range from 0 to 100, with levels above 70 typically considered overbought
     * and levels below 30 considered oversold.
     */
    struct RSIResult {
        /// Array of calculated RSI values (nil for periods with insufficient data)
        let values: [Double?]
        /// The period used for RSI calculation
        let period: Int
        /// RSI level threshold for overbought conditions
        let overboughtLevel: Double
        /// RSI level threshold for oversold conditions
        let oversoldLevel: Double
    }
    
    /**
     * Result structure for volume analysis calculations.
     *
     * Provides volume-based insights including volume ratios compared to average
     * and identification of high-volume periods that may indicate significant market activity.
     */
    struct VolumeAnalysis {
        /// Raw volume data
        let volumes: [Double]
        /// Ratio of current volume to average volume (1.0 = average, >1.0 = above average)
        let volumeRatio: [Double]
        /// Boolean flags indicating periods of high volume (>1.5x average)
        let isHighVolume: [Bool]
    }
    
    // MARK: - Simple Moving Average (SMA)
    
    /**
     * Calculates Simple Moving Average (SMA) for the given price data.
     *
     * SMA is calculated by taking the arithmetic mean of a given set of prices over a specific period.
     * It's a lagging indicator that smooths out price fluctuations to identify trend direction.
     *
     * Formula: SMA = (P1 + P2 + ... + Pn) / n
     * Where P = price at each period, n = number of periods
     *
     * - Parameters:
     *   - prices: Array of price values (typically closing prices)
     *   - period: Number of periods to include in the moving average calculation
     *
     * - Returns: MovingAverageResult containing calculated SMA values and metadata
     *
     * - Note: Returns nil values for the first (period-1) data points where calculation isn't possible
     */
    static func calculateSMA(prices: [Double], period: Int) -> MovingAverageResult {
        // Validate input parameters
        guard !prices.isEmpty, period > 0, prices.count >= period else {
            return MovingAverageResult(values: Array(repeating: nil, count: prices.count), period: period, type: .simple)
        }
        
        // Initialize result array with nil values for insufficient data periods
        var smaValues: [Double?] = Array(repeating: nil, count: period - 1)
        
        // Calculate SMA for each valid period
        for i in (period - 1)..<prices.count {
            let sum = prices[(i - period + 1)...i].reduce(0, +)
            let average = sum / Double(period)
            
            // Validate calculation result to prevent NaN/infinite values
            if average.isFinite {
                smaValues.append(average)
            } else {
                smaValues.append(nil)
            }
        }
        
        return MovingAverageResult(values: smaValues, period: period, type: .simple)
    }
    
    // MARK: - Exponential Moving Average (EMA)
    
    /**
     * Calculates Exponential Moving Average (EMA) for the given price data.
     *
     * EMA gives more weight to recent prices, making it more responsive to new information
     * compared to SMA. It's calculated using a smoothing factor (multiplier) that determines
     * how much weight recent prices receive.
     *
     * Formula: EMA = (Price × Multiplier) + (Previous EMA × (1 - Multiplier))
     * Where Multiplier = 2 / (period + 1)
     *
     * - Parameters:
     *   - prices: Array of price values (typically closing prices)
     *   - period: Number of periods for EMA calculation (affects responsiveness)
     *
     * - Returns: MovingAverageResult containing calculated EMA values and metadata
     *
     * - Note: First EMA value is calculated as SMA, subsequent values use exponential smoothing
     */
    static func calculateEMA(prices: [Double], period: Int) -> MovingAverageResult {
        // Validate input parameters
        guard prices.count >= period, period > 0 else {
            return MovingAverageResult(values: Array(repeating: nil, count: prices.count), period: period, type: .exponential)
        }
        
        // Calculate smoothing multiplier (determines weight of recent prices)
        let multiplier = 2.0 / Double(period + 1)
        
        // Validate multiplier to prevent calculation errors
        guard multiplier.isFinite && multiplier > 0 else {
            return MovingAverageResult(values: Array(repeating: nil, count: prices.count), period: period, type: .exponential)
        }
        
        // Initialize result array with nil values for insufficient data periods
        var emaValues: [Double?] = Array(repeating: nil, count: period - 1)
        
        // Calculate first EMA value using SMA approach
        let firstSum = prices[0..<period].reduce(0, +)
        let firstEMA = firstSum / Double(period)
        
        // Validate first EMA calculation
        if firstEMA.isFinite {
            emaValues.append(firstEMA)
        } else {
            emaValues.append(nil)
        }
        
        // Calculate subsequent EMA values using exponential smoothing
        for i in period..<prices.count {
            guard let previousEMA = emaValues.last as? Double else {
                emaValues.append(nil)
                continue
            }
            
            // Apply exponential smoothing formula
            let currentEMA = (prices[i] * multiplier) + (previousEMA * (1 - multiplier))
            
            // Validate calculation result
            if currentEMA.isFinite {
                emaValues.append(currentEMA)
            } else {
                emaValues.append(nil)
            }
        }
        
        return MovingAverageResult(values: emaValues, period: period, type: .exponential)
    }
    
    // MARK: - RSI (Relative Strength Index)
    
    /**
     * Calculates Relative Strength Index (RSI) for the given price data.
     *
     * RSI is a momentum oscillator that measures the speed and magnitude of price changes.
     * It oscillates between 0 and 100, helping identify overbought and oversold conditions.
     * Values above 70 typically indicate overbought conditions (potential sell signals),
     * while values below 30 indicate oversold conditions (potential buy signals).
     *
     * Formula:
     * RSI = 100 - (100 / (1 + RS))
     * RS (Relative Strength) = Average Gain / Average Loss
     *
     * The calculation uses smoothed averages (Wilder's smoothing) rather than simple averages.
     *
     * - Parameters:
     *   - prices: Array of price values (typically closing prices)
     *   - period: Number of periods for RSI calculation (default: 14, typical range: 9-25)
     *   - overbought: RSI level considered overbought (default: 70)
     *   - oversold: RSI level considered oversold (default: 30)
     *
     * - Returns: RSIResult containing calculated RSI values and threshold levels
     *
     * - Note: Requires at least (period + 1) price points for calculation
     */
    static func calculateRSI(prices: [Double], period: Int = 14, overbought: Double = 70, oversold: Double = 30) -> RSIResult {
        // Validate input - need at least period + 1 prices for calculation
        guard prices.count > period else {
            return RSIResult(values: Array(repeating: nil, count: prices.count), period: period, overboughtLevel: overbought, oversoldLevel: oversold)
        }
        
        // Initialize result array with nil values for insufficient data periods
        var rsiValues: [Double?] = Array(repeating: nil, count: period)
        var gains: [Double] = []
        var losses: [Double] = []
        
        // Calculate price changes and separate gains from losses
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            gains.append(change > 0 ? change : 0)        // Positive changes only
            losses.append(change < 0 ? abs(change) : 0)   // Negative changes as positive values
        }
        
        // Ensure we have enough data for initial calculation
        guard gains.count >= period && losses.count >= period else {
            return RSIResult(values: Array(repeating: nil, count: prices.count), period: period, overboughtLevel: overbought, oversoldLevel: oversold)
        }
        
        // Calculate initial average gain and loss (simple averages for first calculation)
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        // Calculate first RSI value
        let rs1: Double
        if avgLoss == 0 {
            // Handle division by zero - if no losses, RS approaches infinity
            rs1 = avgGain > 0 ? 100 : 0
        } else {
            rs1 = avgGain / avgLoss
        }
        
        // Convert to RSI (0-100 scale)
        let rsi1 = 100 - (100 / (1 + rs1))
        
        // Validate first RSI calculation and ensure it's within expected range
        if rsi1.isFinite && rsi1 >= 0 && rsi1 <= 100 {
            rsiValues.append(rsi1)
        } else {
            rsiValues.append(nil)
        }
        
        // Calculate subsequent RSI values using Wilder's smoothing method
        for i in period..<gains.count {
            // Apply Wilder's smoothing: New Average = ((Previous Average × 13) + Today's Value) ÷ 14
            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
            
            // Validate intermediate calculations
            guard avgGain.isFinite && avgLoss.isFinite && avgGain >= 0 && avgLoss >= 0 else {
                rsiValues.append(nil)
                continue
            }
            
            // Calculate Relative Strength (RS)
            let rs: Double
            if avgLoss == 0 {
                rs = avgGain > 0 ? 100 : 0
            } else {
                rs = avgGain / avgLoss
            }
            
            // Calculate RSI from RS
            let rsi = 100 - (100 / (1 + rs))
            
            // Validate final RSI calculation
            if rsi.isFinite && rsi >= 0 && rsi <= 100 {
                rsiValues.append(rsi)
            } else {
                rsiValues.append(nil)
            }
        }
        
        return RSIResult(values: rsiValues, period: period, overboughtLevel: overbought, oversoldLevel: oversold)
    }
    // MARK: - Volume Analysis
    
    /**
     * Analyzes volume data to identify patterns and unusual trading activity.
     *
     * Volume analysis helps identify the strength behind price movements. High volume often
     * confirms price trends, while low volume may indicate weak or unsustainable moves.
     * This function calculates volume ratios compared to average volume and flags periods
     * of unusually high trading activity.
     *
     * - Parameters:
     *   - volumes: Array of volume values for each time period
     *   - period: Number of periods to use for volume average calculation (default: 20)
     *
     * - Returns: VolumeAnalysis containing volume ratios and high-volume period flags
     *
     * - Note: High volume is defined as 1.5x or greater than the average volume
     */
    static func analyzeVolume(volumes: [Double], period: Int = 20) -> VolumeAnalysis {
        // Calculate moving average of volume using SMA
        let volumeMA = calculateSMA(prices: volumes, period: period)
        
        var volumeRatio: [Double] = []
        var isHighVolume: [Bool] = []
        
        // Calculate volume ratio for each period
        for i in 0..<volumes.count {
            if let avgVolume = volumeMA.values[i], avgVolume > 0 {
                // Calculate ratio of current volume to average volume
                let ratio = volumes[i] / avgVolume
                volumeRatio.append(ratio)
                // Flag periods with volume 50% above average as high-volume
                isHighVolume.append(ratio > 1.5)
            } else {
                // Handle cases where average volume isn't available or is zero
                volumeRatio.append(1.0)  // Neutral ratio
                isHighVolume.append(false)
            }
        }
        
        return VolumeAnalysis(
            volumes: volumes,
            volumeRatio: volumeRatio,
            isHighVolume: isHighVolume
        )
    }
    // MARK: - UserDefaults Integration
    
    /**
     * Saves indicator settings to UserDefaults for persistence across app sessions.
     *
     * This allows users' technical indicator preferences to be remembered between
     * app launches, providing a consistent user experience.
     *
     * - Parameter settings: IndicatorSettings instance to save
     *
     * - Note: Settings are encoded as JSON and stored with key "TechnicalIndicatorSettings"
     */
    static func saveIndicatorSettings(_ settings: IndicatorSettings) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: "TechnicalIndicatorSettings")
        }
    }
    
    /**
     * Loads previously saved indicator settings from UserDefaults.
     *
     * If no saved settings exist or if there's an error decoding the saved data,
     * returns default settings with all indicators disabled.
     *
     * - Returns: IndicatorSettings instance with either saved or default values
     */
    static func loadIndicatorSettings() -> IndicatorSettings {
        guard let data = UserDefaults.standard.data(forKey: "TechnicalIndicatorSettings"),
              let settings = try? JSONDecoder().decode(IndicatorSettings.self, from: data) else {
            return IndicatorSettings() // Return default settings if none exist
        }
        return settings
    }
    
    // MARK: - Color Management
    
    /**
     * Returns theme-appropriate colors for technical indicators on charts.
     *
     * This function provides consistent color schemes across different chart themes
     * while ensuring indicators remain visually distinct and accessible. Colors are
     * chosen to maintain good contrast and readability in both light and dark modes.
     *
     * Supported Indicators:
     * - "sma": Simple Moving Average
     * - "ema": Exponential Moving Average  
     * - "rsi": Relative Strength Index
     * - "volume": Volume bars
     *
     * - Parameters:
     *   - indicator: String identifier for the technical indicator
     *   - theme: ChartColorTheme to determine color scheme
     *
     * - Returns: UIColor appropriate for the indicator and theme
     *
     * - Note: Returns UIColor.label as fallback for unknown indicators
     */
    static func getIndicatorColor(for indicator: String, theme: ChartColorTheme) -> UIColor {
        switch indicator.lowercased() {
        case "sma":
            switch theme {
            case .classic: return UIColor.systemBlue      // Traditional blue for primary MA
            case .ocean: return UIColor.systemCyan        // Ocean-themed cyan
            case .monochrome: return UIColor.systemGray   // Neutral gray for monochrome
            case .accessibility: return UIColor.systemBlue // High contrast blue
            }
            
        case "ema":
            switch theme {
            case .classic: return UIColor.systemOrange    // Distinct from SMA
            case .ocean: return UIColor.systemYellow      // Warm contrast to ocean blues
            case .monochrome: return UIColor.systemGray2  // Slightly different gray
            case .accessibility: return UIColor.systemOrange // High contrast orange
            }
            
        case "rsi":
            switch theme {
            case .classic: return UIColor.systemPurple    // Purple for momentum oscillator
            case .ocean: return UIColor.systemIndigo      // Deep ocean color
            case .monochrome: return UIColor.systemGray3  // Medium gray
            case .accessibility: return UIColor.systemPurple // High contrast purple
            }
            
        case "volume":
            switch theme {
            case .classic: return UIColor.systemGreen     // Green for volume bars
            case .ocean: return UIColor.systemBlue        // Ocean blue
            case .monochrome: return UIColor.lightGray    // Light gray for volume
            case .accessibility: return UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0) // High contrast green
            }
            
        default:
            return UIColor.label // Fallback to system label color for unknown indicators
        }
    }
}

// MARK: - Codable Support for Settings

/**
 * Codable conformance for IndicatorSettings to enable JSON serialization.
 *
 * This extension allows IndicatorSettings to be easily encoded to and decoded from
 * JSON format for persistent storage in UserDefaults. All properties in IndicatorSettings
 * are automatically codable since they use standard Swift types.
 */
extension TechnicalIndicators.IndicatorSettings: Codable {}
