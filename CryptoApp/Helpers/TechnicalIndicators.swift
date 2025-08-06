//
//  TechnicalIndicators.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
//

import Foundation
import UIKit

/// Technical indicator calculation helper for crypto chart analysis
final class TechnicalIndicators {
    
    // MARK: - Indicator Configuration
    
    struct IndicatorSettings {
        // Moving Averages
        var showSMA: Bool = false
        var smaPeriod: Int = 20
        var showEMA: Bool = false
        var emaPeriod: Int = 12
        
        // RSI
        var showRSI: Bool = false
        var rsiPeriod: Int = 14
        var rsiOverbought: Double = 70
        var rsiOversold: Double = 30
        
        // Volume
        var showVolume: Bool = false
        var showVolumeMA: Bool = false
        var volumeMAPeriod: Int = 20
    }
    
    // MARK: - Indicator Results
    
    struct MovingAverageResult {
        let values: [Double?]
        let period: Int
        let type: MovingAverageType
        
        enum MovingAverageType {
            case simple, exponential
        }
    }
    
    struct RSIResult {
        let values: [Double?]
        let period: Int
        let overboughtLevel: Double
        let oversoldLevel: Double
    }
    

    
    struct VolumeAnalysis {
        let volumes: [Double]
        let volumeMA: [Double?]
        let volumeRatio: [Double]  // Current volume / average volume
        let isHighVolume: [Bool]   // Above average volume
    }
    
    // MARK: - Simple Moving Average (SMA)
    
    static func calculateSMA(prices: [Double], period: Int) -> MovingAverageResult {
        // Validate input
        guard !prices.isEmpty, period > 0, prices.count >= period else {
            return MovingAverageResult(values: Array(repeating: nil, count: prices.count), period: period, type: .simple)
        }
        
        var smaValues: [Double?] = Array(repeating: nil, count: period - 1)
        
        for i in (period - 1)..<prices.count {
            let sum = prices[(i - period + 1)...i].reduce(0, +)
            let average = sum / Double(period)
            
            // Check for NaN or infinite values
            if average.isFinite {
                smaValues.append(average)
            } else {
                smaValues.append(nil)
            }
        }
        
        return MovingAverageResult(values: smaValues, period: period, type: .simple)
    }
    
    // MARK: - Exponential Moving Average (EMA)
    
    static func calculateEMA(prices: [Double], period: Int) -> MovingAverageResult {
        guard prices.count >= period else {
            return MovingAverageResult(values: Array(repeating: nil, count: prices.count), period: period, type: .exponential)
        }
        
        let multiplier = 2.0 / Double(period + 1)
        var emaValues: [Double?] = Array(repeating: nil, count: period - 1)
        
        // First EMA value is SMA
        let firstSum = prices[0..<period].reduce(0, +)
        let firstEMA = firstSum / Double(period)
        emaValues.append(firstEMA)
        
        // Calculate subsequent EMA values
        for i in period..<prices.count {
            guard let previousEMA = emaValues.last as? Double else {
                emaValues.append(nil)
                continue
            }
            
            let currentEMA = (prices[i] * multiplier) + (previousEMA * (1 - multiplier))
            
            // Check for NaN or infinite values
            if currentEMA.isFinite {
                emaValues.append(currentEMA)
            } else {
                emaValues.append(nil)
            }
        }
        
        return MovingAverageResult(values: emaValues, period: period, type: .exponential)
    }
    
    // MARK: - RSI (Relative Strength Index)
    
    static func calculateRSI(prices: [Double], period: Int = 14, overbought: Double = 70, oversold: Double = 30) -> RSIResult {
        guard prices.count > period else {
            return RSIResult(values: Array(repeating: nil, count: prices.count), period: period, overboughtLevel: overbought, oversoldLevel: oversold)
        }
        
        var rsiValues: [Double?] = Array(repeating: nil, count: period)
        var gains: [Double] = []
        var losses: [Double] = []
        
        // Calculate price changes
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            gains.append(change > 0 ? change : 0)
            losses.append(change < 0 ? abs(change) : 0)
        }
        
        // Calculate initial average gain and loss
        guard gains.count >= period && losses.count >= period else {
            return RSIResult(values: Array(repeating: nil, count: prices.count), period: period, overboughtLevel: overbought, oversoldLevel: oversold)
        }
        
        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)
        
        // Calculate first RSI
        let rs1: Double
        if avgLoss == 0 {
            rs1 = avgGain > 0 ? 100 : 0
        } else {
            rs1 = avgGain / avgLoss
        }
        
        let rsi1 = 100 - (100 / (1 + rs1))
        
        // Check for NaN or infinite values
        if rsi1.isFinite && rsi1 >= 0 && rsi1 <= 100 {
            rsiValues.append(rsi1)
        } else {
            rsiValues.append(nil)
        }
        
        // Calculate subsequent RSI values using smoothed averages
        for i in period..<gains.count {
            avgGain = ((avgGain * Double(period - 1)) + gains[i]) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + losses[i]) / Double(period)
            
            let rs: Double
            if avgLoss == 0 {
                rs = avgGain > 0 ? 100 : 0
            } else {
                rs = avgGain / avgLoss
            }
            
            let rsi = 100 - (100 / (1 + rs))
            
            // Check for NaN or infinite values
            if rsi.isFinite && rsi >= 0 && rsi <= 100 {
                rsiValues.append(rsi)
            } else {
                rsiValues.append(nil)
            }
        }
        
        return RSIResult(values: rsiValues, period: period, overboughtLevel: overbought, oversoldLevel: oversold)
    }
    

    

    
    // MARK: - Volume Analysis
    
    static func analyzeVolume(volumes: [Double], period: Int = 20) -> VolumeAnalysis {
        let volumeMA = calculateSMA(prices: volumes, period: period)
        
        var volumeRatio: [Double] = []
        var isHighVolume: [Bool] = []
        
        for i in 0..<volumes.count {
            if let avgVolume = volumeMA.values[i], avgVolume > 0 {
                let ratio = volumes[i] / avgVolume
                volumeRatio.append(ratio)
                isHighVolume.append(ratio > 1.5) // 50% above average is considered high
            } else {
                volumeRatio.append(1.0)
                isHighVolume.append(false)
            }
        }
        
        return VolumeAnalysis(
            volumes: volumes,
            volumeMA: volumeMA.values,
            volumeRatio: volumeRatio,
            isHighVolume: isHighVolume
        )
    }
    

    
    // MARK: - UserDefaults Integration
    
    static func saveIndicatorSettings(_ settings: IndicatorSettings) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: "TechnicalIndicatorSettings")
        }
    }
    
    static func loadIndicatorSettings() -> IndicatorSettings {
        guard let data = UserDefaults.standard.data(forKey: "TechnicalIndicatorSettings"),
              let settings = try? JSONDecoder().decode(IndicatorSettings.self, from: data) else {
            return IndicatorSettings() // Return default settings
        }
        return settings
    }
    
    // MARK: - Color Management
    
    /// Returns appropriate colors for different technical indicators based on theme
    static func getIndicatorColor(for indicator: String, theme: ChartColorTheme) -> UIColor {
        switch indicator.lowercased() {
        case "sma":
            switch theme {
            case .classic: return UIColor.systemBlue
            case .ocean: return UIColor.systemCyan
            case .monochrome: return UIColor.systemGray
            case .accessibility: return UIColor.systemBlue
            }
            
        case "ema":
            switch theme {
            case .classic: return UIColor.systemOrange
            case .ocean: return UIColor.systemYellow
            case .monochrome: return UIColor.systemGray2
            case .accessibility: return UIColor.systemOrange
            }
            
        case "rsi":
            switch theme {
            case .classic: return UIColor.systemPurple
            case .ocean: return UIColor.systemIndigo
            case .monochrome: return UIColor.systemGray3
            case .accessibility: return UIColor.systemPurple
            }
            
        case "macd":
            switch theme {
            case .classic: return UIColor.systemTeal
            case .ocean: return UIColor.systemMint
            case .monochrome: return UIColor.systemGray4
            case .accessibility: return UIColor.systemTeal
            }
            
        case "macd_signal":
            switch theme {
            case .classic: return UIColor.systemRed
            case .ocean: return UIColor.systemPink
            case .monochrome: return UIColor.systemGray5
            case .accessibility: return UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0)
            }
            
        case "bollinger_upper", "bollinger_lower":
            switch theme {
            case .classic: return UIColor.systemGray
            case .ocean: return UIColor.systemBrown
            case .monochrome: return UIColor.systemGray6
            case .accessibility: return UIColor.systemGray
            }
            
        case "volume":
            switch theme {
            case .classic: return UIColor.systemGreen
            case .ocean: return UIColor.systemBlue
            case .monochrome: return UIColor.lightGray
            case .accessibility: return UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)
            }
            
        default:
            return UIColor.label // Fallback to system label color
        }
    }
}

// MARK: - Codable Support for Settings

extension TechnicalIndicators.IndicatorSettings: Codable {}