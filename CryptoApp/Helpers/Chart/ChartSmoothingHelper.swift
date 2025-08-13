//
//  ChartSmoothingHelper.swift
//  CryptoApp
//
//


/**
 * ALGORITHM TYPES (5 Essential Algorithms):
 * Basic: Evenly smoothed gentle curves
 * Adaptive: Chooses the best smoothing method based on time range  
 * Savitzky-Golay: Smooth but keeps important peaks (crypto-optimized)
 * Median: Clean with spikes removed (data cleaning)
 * LOESS: Ultra-smooth organic flowing curves (presentations)
 */

import Foundation

/// Helper class for applying various smoothing algorithms to chart data
final class ChartSmoothingHelper {
    
    // MARK: - Smoothing Algorithm Types
    
    enum SmoothingType: String {
        case basic = "basic"              // Simple moving average
        case adaptive = "adaptive"        // Range-based adaptive smoothing
        case savitzkyGolay = "savitzkyGolay"  // Preserves peaks (great for crypto)
        case median = "median"            // Removes spikes
        case loess = "loess"              // Local regression (follows trends)
    }
    
    // MARK: - Main Smoothing Function
    
    /// Applies smoothing based on selected algorithm and time range
    static func applySmoothingToChartData(_ data: [Double], type: SmoothingType, timeRange: String) -> [Double] {
        guard data.count > 3 else { return data }
        
        switch type {
        case .basic:
            // Creates uniform smoothing with equal weight for nearby points
            // Result: Simple, clean lines that reduce noise evenly across the chart
            let windowSize = getBasicWindowSize(for: timeRange)
            return applySimpleMovingAverage(data, windowSize: windowSize)
            
        case .adaptive:
            // Automatically chooses the best smoothing method based on time range
            // Result: Smart smoothing - light for short periods, heavy for long periods
            return applyAdaptiveTimeRangeSmoothing(data, for: timeRange)
            
        case .savitzkyGolay:
            // Preserves important peaks and valleys while smoothing the overall trend
            // Result: Clean lines that keep price spikes and dips visible for analysis
            let windowSize = getSavitzkyGolayWindow(for: timeRange)
            return applySavitzkyGolayFilter(data, windowSize: windowSize)
            
        case .median:
            // Removes sudden price spikes and data errors while keeping normal trends
            // Result: Eliminates flash crashes and API glitches from the chart
            let windowSize = getMedianWindowSize(for: timeRange)
            return applyMedianFilter(data, windowSize: windowSize)
            
        case .loess:
            // Creates ultra-smooth flowing curves using local regression
            // Result: Smooth curves that bend and flow with market trends naturally
            let bandwidth = getLOESSBandwidth(for: timeRange)
            return applyLOESSSmoothing(data, bandwidth: bandwidth)
        }
    }
    
    /// Removes obvious outliers that could be API errors or data spikes
    static func removeOutliers(_ data: [Double]) -> [Double] {
        guard data.count > 10 else { return data }
        
        // Calculate median and MAD (Median Absolute Deviation)
        let sortedData = data.sorted()
        let median = sortedData[sortedData.count / 2]
        
        let deviations = data.map { abs($0 - median) }
        let sortedDeviations = deviations.sorted()
        let mad = sortedDeviations[sortedDeviations.count / 2]
        
        // Remove points that are more than 3 MADs away from median
        let threshold = 3.0 * mad
        
        return data.map { value in
            let deviation = abs(value - median)
            return deviation > threshold ? median : value
        }
    }
    
    // MARK: - Basic Smoothing Algorithms
    
    /// Simple Moving Average - Reduces noise while preserving trends
    private static func applySimpleMovingAverage(_ data: [Double], windowSize: Int) -> [Double] {
        guard data.count >= windowSize else { return data }
        
        var smoothedData: [Double] = []
        
        // Keep first few points as-is to preserve start of chart
        for i in 0..<windowSize-1 {
            smoothedData.append(data[i])
        }
        
        // Apply moving average to the rest
        for i in windowSize-1..<data.count {
            let windowStart = i - windowSize + 1
            let windowSum = data[windowStart...i].reduce(0, +)
            let average = windowSum / Double(windowSize)
            smoothedData.append(average)
        }
        
        return smoothedData
    }
    
    /// Exponential Moving Average - Gives more weight to recent prices
    private static func applyExponentialMovingAverage(_ data: [Double], alpha: Double) -> [Double] {
        guard !data.isEmpty else { return data }
        
        var smoothedData: [Double] = []
        smoothedData.append(data[0]) // First value stays the same
        
        for i in 1..<data.count {
            let ema = alpha * data[i] + (1 - alpha) * smoothedData[i-1]
            smoothedData.append(ema)
        }
        
        return smoothedData
    }
    
    // MARK: - Advanced Smoothing Algorithms
    
    /// Savitzky-Golay filter - Preserves peaks while smoothing (great for crypto!)
    private static func applySavitzkyGolayFilter(_ data: [Double], windowSize: Int = 5) -> [Double] {
        guard data.count > windowSize, windowSize >= 3 else { return data }
        
        var smoothedData = data
        let halfWindow = windowSize / 2
        
        // Savitzky-Golay coefficients for polynomial order 2
        let coefficients = generateSavitzkyGolayCoefficients(windowSize: windowSize)
        
        for i in halfWindow..<(data.count - halfWindow) {
            var sum: Double = 0
            for j in 0..<windowSize {
                let dataIndex = i - halfWindow + j
                sum += data[dataIndex] * coefficients[j]
            }
            smoothedData[i] = sum
        }
        
        return smoothedData
    }
    
    /// Generate Savitzky-Golay coefficients
    private static func generateSavitzkyGolayCoefficients(windowSize: Int) -> [Double] {
        // Pre-calculated coefficients for common window sizes
        switch windowSize {
        case 3: return [-0.083, 0.583, 0.5]
        case 5: return [-0.086, 0.343, 0.486, 0.343, -0.086]
        case 7: return [-0.095, 0.143, 0.286, 0.333, 0.286, 0.143, -0.095]
        default: return Array(repeating: 1.0 / Double(windowSize), count: windowSize)
        }
    }
    
    /// Median filter - Excellent for removing price spikes and outliers
    private static func applyMedianFilter(_ data: [Double], windowSize: Int = 5) -> [Double] {
        guard data.count > windowSize else { return data }
        
        var filteredData = data
        let halfWindow = windowSize / 2
        
        for i in halfWindow..<(data.count - halfWindow) {
            let window = Array(data[(i - halfWindow)...(i + halfWindow)])
            filteredData[i] = window.sorted()[halfWindow]
        }
        
        return filteredData
    }
    
    /// LOESS (Local Regression) - Adaptive smoothing that follows data trends
    private static func applyLOESSSmoothing(_ data: [Double], bandwidth: Double = 0.3) -> [Double] {
        guard data.count > 10 else { return data }
        
        var smoothedData: [Double] = []
        let n = data.count
        let h = Int(bandwidth * Double(n))
        
        for i in 0..<n {
            let weights = calculateLOESSWeights(index: i, data: data, bandwidth: h)
            let smoothedValue = calculateWeightedAverage(data: data, weights: weights)
            smoothedData.append(smoothedValue)
        }
        
        return smoothedData
    }
    
    /// Calculate LOESS weights with NaN validation
    private static func calculateLOESSWeights(index: Int, data: [Double], bandwidth: Int) -> [Double] {
        var weights = Array(repeating: 0.0, count: data.count)
        
        // Validate bandwidth to prevent division by zero
        guard bandwidth > 0 else {
            return weights
        }
        
        for j in 0..<data.count {
            let distance = abs(Double(j - index))
            if distance <= Double(bandwidth) {
                let u = distance / Double(bandwidth)
                
                // Validate u before pow operations
                guard u.isFinite && u >= 0 && u <= 1 else {
                    continue
                }
                
                let u3 = pow(u, 3)
                let weight = pow(1 - u3, 3) // Tricube weight function
                
                // Validate final weight
                if weight.isFinite && weight >= 0 {
                    weights[j] = weight
                }
            }
        }
        
        return weights
    }
    
    /// Calculate weighted average for LOESS with NaN validation
    private static func calculateWeightedAverage(data: [Double], weights: [Double]) -> Double {
        let weightedSum = zip(data, weights).map { $0 * $1 }.reduce(0, +)
        let totalWeight = weights.reduce(0, +)
        
        // Validate calculations before division
        guard weightedSum.isFinite && totalWeight.isFinite && totalWeight > 0 else {
            return data.isEmpty ? 0 : (data.reduce(0, +) / Double(data.count))
        }
        
        let result = weightedSum / totalWeight
        return result.isFinite ? result : 0
    }
    
    /// Apply convolution for filtering
    private static func applyConvolution(_ data: [Double], kernel: [Double]) -> [Double] {
        guard kernel.count <= data.count else { return data }
        
        var result = data
        let halfKernel = kernel.count / 2
        
        for i in halfKernel..<(data.count - halfKernel) {
            var sum: Double = 0
            for j in 0..<kernel.count {
                let dataIndex = i - halfKernel + j
                sum += data[dataIndex] * kernel[j]
            }
            result[i] = sum
        }
        
        return result
    }
    
    // MARK: - Adaptive Range Smoothing
    
    /// Original adaptive smoothing based on time range
    private static func applyAdaptiveTimeRangeSmoothing(_ data: [Double], for days: String) -> [Double] {
        switch days {
        case "1": return applySimpleMovingAverage(data, windowSize: 3)
        case "7": return applySimpleMovingAverage(data, windowSize: 5)
        case "30": return applyExponentialMovingAverage(data, alpha: 0.3)
        case "365": return applyExponentialMovingAverage(data, alpha: 0.2)
        default: return applySimpleMovingAverage(data, windowSize: 5)
        }
    }
    
    // MARK: - Parameter Helpers
    
    private static func getBasicWindowSize(for days: String) -> Int {
        switch days {
        case "1": return 3
        case "7": return 5
        case "30": return 7
        case "365": return 10
        default: return 5
        }
    }
    
    private static func getSavitzkyGolayWindow(for days: String) -> Int {
        switch days {
        case "1": return 3
        case "7": return 5
        case "30": return 7
        case "365": return 7
        default: return 5
        }
    }
    
    private static func getMedianWindowSize(for days: String) -> Int {
        switch days {
        case "1": return 3
        case "7": return 5
        case "30": return 7
        case "365": return 9
        default: return 5
        }
    }
    
    private static func getLOESSBandwidth(for days: String) -> Double {
        switch days {
        case "1": return 0.2    // Less smoothing for 24h
        case "7": return 0.3    // Medium smoothing for 7d
        case "30": return 0.4   // More smoothing for 30d
        case "365": return 0.5  // Heavy smoothing for all-time
        default: return 0.3
        }
    }
}
