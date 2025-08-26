//
//  ChartLabelManager.swift
//  CryptoApp
//
//

import Foundation
import UIKit
import DGCharts

/// Manages dynamic labels for technical indicators on charts
class ChartLabelManager {
    
    // MARK: - Label Container Views
    
    private var topLabelsContainer: UIStackView?
    private var rsiLabelContainer: UIView?
    private weak var parentChart: UIView?
    
    // MARK: - Individual Labels
    
    private var smaLabel: UILabel?
    private var emaLabel: UILabel?
    private var rsiLabel: UILabel?
    private var currentPriceLabel: UILabel?
    
    // MARK: - Initialization
    
    init(parentChart: UIView) {
        self.parentChart = parentChart
        setupLabelContainers()
    }
    
    // MARK: - Setup
    
    private func setupLabelContainers() {
        guard let parentChart = parentChart else { return }
        
        // Create top labels container for Current Price/SMA/EMA values (similar to CoinMarketCap)
        topLabelsContainer = UIStackView()
        topLabelsContainer?.axis = .horizontal
        topLabelsContainer?.spacing = 12 // Tighter spacing to fit all three labels
        topLabelsContainer?.alignment = .center
        topLabelsContainer?.distribution = .fillProportionally
        topLabelsContainer?.translatesAutoresizingMaskIntoConstraints = false
        
        // Create RSI label container
        rsiLabelContainer = UIView()
        rsiLabelContainer?.translatesAutoresizingMaskIntoConstraints = false
        
        // Add containers to parent chart
        if let topContainer = topLabelsContainer {
            parentChart.addSubview(topContainer)
            NSLayoutConstraint.activate([
                topContainer.topAnchor.constraint(equalTo: parentChart.topAnchor, constant: 8),
                topContainer.leadingAnchor.constraint(equalTo: parentChart.leadingAnchor, constant: 12),
                topContainer.trailingAnchor.constraint(lessThanOrEqualTo: parentChart.trailingAnchor, constant: -12)
            ])
        }
        
        if let rsiContainer = rsiLabelContainer {
            parentChart.addSubview(rsiContainer)
            // RSI label will be positioned dynamically based on RSI area
        }
        
        setupIndividualLabels()
    }
    
    private func setupIndividualLabels() {
        // Current Price Label (first in line)
        currentPriceLabel = createCurrentPriceLabel()
        currentPriceLabel?.isHidden = true
        
        // SMA Label (smaller font)
        smaLabel = createTechnicalIndicatorLabel()
        smaLabel?.isHidden = true
        
        // EMA Label (smaller font)
        emaLabel = createTechnicalIndicatorLabel()
        emaLabel?.isHidden = true
        
        // RSI Label (styled differently)
        rsiLabel = createRSILabel()
        rsiLabel?.isHidden = true
        
        // Add labels to containers
        if let topContainer = topLabelsContainer {
            if let smaLabel = smaLabel { topContainer.addArrangedSubview(smaLabel) }
            if let emaLabel = emaLabel { topContainer.addArrangedSubview(emaLabel) }
            if let priceLabel = currentPriceLabel { topContainer.addArrangedSubview(priceLabel) }
        }
        
        if let rsiContainer = rsiLabelContainer, let rsiLabel = rsiLabel {
            rsiContainer.addSubview(rsiLabel)
            NSLayoutConstraint.activate([
                rsiLabel.leadingAnchor.constraint(equalTo: rsiContainer.leadingAnchor, constant: 8),
                rsiLabel.centerYAnchor.constraint(equalTo: rsiContainer.centerYAnchor)
            ])
        }
    }
    
    private func createCurrentPriceLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium) // Same size as SMA/EMA
        label.textAlignment = .left
        label.backgroundColor = UIColor.clear
        return label
    }
    
    private func createTechnicalIndicatorLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium) // Smaller font to fit all three
        label.textAlignment = .left
        label.backgroundColor = UIColor.clear
        return label
    }
    
    private func createRSILabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false  // Fix AutoLayout conflicts
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textAlignment = .left
        label.textColor = UIColor.systemGray
        label.backgroundColor = UIColor.clear
        return label
    }
    
    // MARK: - Public Update Methods
    
    /// Creates an intelligent message for insufficient technical indicator data
    private func getInsufficientDataMessage(for indicatorType: String, period: Int, availableDataCount: Int) -> String {
        let needed = period + (indicatorType == "RSI" ? 1 : 0) // RSI needs period + 1
        let remaining = needed - availableDataCount
        
        if availableDataCount == 0 {
            return "\(indicatorType)(\(period)): No data available"
        } else if remaining > 0 {
            if remaining == 1 {
                return "\(indicatorType)(\(period)): Need 1 more data point"
            } else {
                return "\(indicatorType)(\(period)): Need \(remaining) more data points"
            }
        } else {
            return "\(indicatorType)(\(period)): Need more data"
        }
    }
    
    /// Updates SMA label with current value and settings
    func updateSMALabel(value: Double?, period: Int, color: UIColor, isVisible: Bool, dataCount: Int = 0) {
        guard let smaLabel = smaLabel else { return }
        
        smaLabel.isHidden = !isVisible
        
        if isVisible {
            if let value = value {
                let formattedValue = formatCurrency(value)
                smaLabel.text = "SMA(\(period)): \(formattedValue)"
                smaLabel.textColor = color
            } else {
                // Check if we have sufficient data but the line is just not visible at current position
                if dataCount >= period {
                    smaLabel.text = "SMA(\(period)): Not visible"
                    smaLabel.textColor = UIColor.systemGray2
                } else {
                    // Show intelligent message for insufficient data
                    smaLabel.text = getInsufficientDataMessage(for: "SMA", period: period, availableDataCount: dataCount)
                    smaLabel.textColor = UIColor.systemGray2
                }
            }
        }
    }
    
    /// Updates EMA label with current value and settings
    func updateEMALabel(value: Double?, period: Int, color: UIColor, isVisible: Bool, dataCount: Int = 0) {
        guard let emaLabel = emaLabel else { return }
        
        emaLabel.isHidden = !isVisible
        
        if isVisible {
            if let value = value {
                let formattedValue = formatCurrency(value)
                emaLabel.text = "EMA(\(period)): \(formattedValue)"
                emaLabel.textColor = color
            } else {
                // Check if we have sufficient data but the line is just not visible at current position
                if dataCount >= period {
                    emaLabel.text = "EMA(\(period)): Not visible"
                    emaLabel.textColor = UIColor.systemGray2
                } else {
                    // Show intelligent message for insufficient data
                    emaLabel.text = getInsufficientDataMessage(for: "EMA", period: period, availableDataCount: dataCount)
                    emaLabel.textColor = UIColor.systemGray2
                }
            }
        }
    }
    
    /// Updates RSI label with current value and settings
    func updateRSILabel(value: Double?, period: Int, isVisible: Bool, dataCount: Int = 0) {
        guard let rsiLabel = rsiLabel else { return }
        
        rsiLabel.isHidden = !isVisible
        
        if isVisible {
            if let value = value {
                let formattedValue = String(format: "%.2f", value)
                rsiLabel.text = "RSI(\(period)): \(formattedValue)"
                rsiLabel.textColor = UIColor.systemGray
            } else {
                // Show intelligent message for insufficient data
                rsiLabel.text = getInsufficientDataMessage(for: "RSI", period: period, availableDataCount: dataCount)
                rsiLabel.textColor = UIColor.systemGray2
            }
        }
    }
    
    /// Positions the RSI label in the RSI chart area
    func positionRSILabel(in chartBounds: CGRect, rsiAreaTop: CGFloat, rsiAreaHeight: CGFloat) {
        guard let rsiContainer = rsiLabelContainer, let parentChart = parentChart else { return }
        
        // Clean up existing constraints and positioning
        rsiContainer.removeFromSuperview()
        
        // Add container back and set up constraints
        parentChart.addSubview(rsiContainer)
        
        // Set constraints - these will be fresh since we removed from superview
        NSLayoutConstraint.activate([
            rsiContainer.leadingAnchor.constraint(equalTo: parentChart.leadingAnchor),
            rsiContainer.trailingAnchor.constraint(equalTo: parentChart.trailingAnchor),
            rsiContainer.topAnchor.constraint(equalTo: parentChart.topAnchor, constant: rsiAreaTop + 4),
            rsiContainer.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Helper Methods
    
    /// Gets the latest values for updating labels
    func getLatestSMAValue(from dataSet: LineChartDataSet?) -> Double? {
        guard let entries = dataSet?.entries, !entries.isEmpty else { return nil }
        return entries.last?.y
    }
    
    func getLatestEMAValue(from dataSet: LineChartDataSet?) -> Double? {
        guard let entries = dataSet?.entries, !entries.isEmpty else { return nil }
        return entries.last?.y
    }
    
    func getLatestRSIValue(from rsiResult: TechnicalIndicators.RSIResult) -> Double? {
        return rsiResult.values.compactMap { $0 }.last
    }
    
    // MARK: - Cleanup
    
    func removeAllLabels() {
        topLabelsContainer?.removeFromSuperview()
        rsiLabelContainer?.removeFromSuperview()
        topLabelsContainer = nil
        rsiLabelContainer = nil
        smaLabel = nil
        emaLabel = nil
        rsiLabel = nil
    }
    
    // MARK: - Dynamic Value Updates (CoinMarketCap Style)
    
    /// Updates the current price label with dynamic price and color
    func updateCurrentPrice(price: Double, isBullish: Bool) {
        guard let label = currentPriceLabel else { return }
        
        // Adaptive price formatting for micro-priced coins
        let formattedPrice: String
        if price >= 1 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formattedPrice = formatter.string(from: NSNumber(value: price)) ?? String(format: "$%.2f", price)
        } else if price > 0 {
            var decimals = 6
            var v = price
            while v < 1 && v > 0 && decimals < 10 {
                v *= 10
                if v >= 1 { break }
                decimals += 1
            }
            let clamped = max(4, min(decimals, 10))
            formattedPrice = String(format: "$%.*f", clamped, price)
        } else {
            formattedPrice = "$0"
        }
        label.text = "Close: \(formattedPrice)"
        
        // Update color based on price movement
        label.textColor = isBullish ? UIColor.systemGreen : UIColor.systemRed
        label.isHidden = false
    }
    
    /// Updates labels with values at specific chart position (for crosshair interaction)
    func updateLabelsAtPosition(
        xIndex: Int,
        smaDataSet: LineChartDataSet?,
        emaDataSet: LineChartDataSet?,
        rsiResult: TechnicalIndicators.RSIResult?,
        settings: TechnicalIndicators.IndicatorSettings,
        theme: ChartColorTheme,
        dataPointCount: Int = 0
    ) {
        // Cache values to avoid duplicate calls
        var smaValue: Double?
        var emaValue: Double?
        var rsiValue: Double?
        
        // Update SMA at position
        if settings.showSMA {
            if let smaDataSet = smaDataSet {
                smaValue = getValueAtIndex(xIndex, from: smaDataSet)
                // If no value found but SMA is enabled, provide helpful context
                if smaValue == nil {
                    // Check if we're before the SMA warm-up period
                    if let firstValidIndex = getFirstValidIndicatorIndex(from: smaDataSet), xIndex < firstValidIndex {
                        // User is viewing a time period before SMA calculation begins
                        print("📍 User scrolled to index \(xIndex), but SMA line starts at index \(firstValidIndex)")
                    }
                }
            }
            let smaColor = TechnicalIndicators.getIndicatorColor(for: "sma", theme: theme)
            updateSMALabel(value: smaValue, period: settings.smaPeriod, color: smaColor, isVisible: true, dataCount: dataPointCount)
        } else {
            smaLabel?.isHidden = true
        }
        
        // Update EMA at position
        if settings.showEMA {
            if let emaDataSet = emaDataSet {
                emaValue = getValueAtIndex(xIndex, from: emaDataSet)
                // If no value found but EMA is enabled, provide helpful context
                if emaValue == nil {
                    // Check if we're before the EMA warm-up period
                    if let firstValidIndex = getFirstValidIndicatorIndex(from: emaDataSet), xIndex < firstValidIndex {
                        // User is viewing a time period before EMA calculation begins
                        print("📍 User scrolled to index \(xIndex), but EMA line starts at index \(firstValidIndex)")
                    }
                }
            }
            let emaColor = TechnicalIndicators.getIndicatorColor(for: "ema", theme: theme)
            updateEMALabel(value: emaValue, period: settings.emaPeriod, color: emaColor, isVisible: true, dataCount: dataPointCount)
        } else {
            emaLabel?.isHidden = true
        }
        
        // Update RSI at position
        if settings.showRSI {
            if let rsiResult = rsiResult {
                rsiValue = getRSIValueAtIndex(xIndex, from: rsiResult)
            }
            updateRSILabel(value: rsiValue, period: settings.rsiPeriod, isVisible: true, dataCount: dataPointCount)
        } else {
            rsiLabel?.isHidden = true
        }
        
        // Summary of what's being monitored (using cached values)
        print("📊 SUMMARY for Index \(xIndex):")
        if settings.showSMA {
            let smaText = smaValue.map { String(format: "%.2f", $0) } ?? "N/A"
            print("   • SMA(\(settings.smaPeriod)): $\(smaText)")
        }
        if settings.showEMA {
            let emaText = emaValue.map { String(format: "%.2f", $0) } ?? "N/A"
            print("   • EMA(\(settings.emaPeriod)): $\(emaText)")
        }
        if settings.showRSI {
            let rsiText = rsiValue.map { String(format: "%.2f", $0) } ?? "N/A"
            print("   • RSI(\(settings.rsiPeriod)): \(rsiText)")
        }
        print("────────────────────────────────────────")
    }
    
    /// Gets value from dataset at specific index, accounting for dataset offset
    private func getValueAtIndex(_ index: Int, from dataSet: LineChartDataSet) -> Double? {
        // For SMA/EMA datasets that start later due to warm-up period,
        // we need to find the corresponding entry by matching x values (timestamps or indices)
        
        guard !dataSet.entries.isEmpty else { 
            print("⚠️ Dataset is empty")
            return nil 
        }
        
        // ENHANCEMENT: Check if the indicator line is actually visible at this index
        // SMA/EMA lines have a warm-up period and don't start from index 0
        let isIndexInVisibleRange = isIndicatorVisibleAtIndex(index, in: dataSet)
        guard isIndexInVisibleRange else {
            print("📍 SMA/EMA line not visible at index \(index) - line starts at index \(getFirstValidIndicatorIndex(from: dataSet) ?? -1)")
            return nil
        }
        
        // Detect coordinate system: check if X values are timestamps (large numbers) or indices (small numbers)
        let firstEntry = dataSet.entries.first!
        let usesTimestamps = firstEntry.x > 10000 // Timestamps are much larger than indices
        
        if usesTimestamps {
            // For timestamp-based datasets (line charts), find entry by index position in the original array
            // Account for nil values filtered out during dataset creation
            let warmupPeriod = getWarmupPeriodFromLabel(dataSet.label)
            let adjustedIndex = index - warmupPeriod
            
            // Ensure adjusted index is valid for the filtered entries array
            if adjustedIndex >= 0 && adjustedIndex < dataSet.entries.count {
                let entry = dataSet.entries[adjustedIndex]
                let value = entry.y
                print("🎯 Timestamp-based: Retrieved \(String(format: "%.2f", value)) at adjusted index \(adjustedIndex) (original index: \(index), warmup: \(warmupPeriod), x: \(String(format: "%.0f", entry.x))) from dataset with \(dataSet.entries.count) entries")
                return value
            }
        } else {
            // For index-based datasets (candlestick charts), use direct X value matching
            let targetX = Double(index)
            
            // Try exact match first
            if let exactEntry = dataSet.entries.first(where: { abs($0.x - targetX) < 0.1 }) {
                let value = exactEntry.y
                print("🎯 Index-based exact: Retrieved \(String(format: "%.2f", value)) at index \(index) (x: \(exactEntry.x)) from dataset with \(dataSet.entries.count) entries")
                return value
            }
        }
        
        // Fallback: Find the entry with the closest x value
        let targetX = usesTimestamps ? firstEntry.x + (Double(index) * 3600) : Double(index) // Rough timestamp estimation for fallback
        var closestEntry: ChartDataEntry?
        var closestDistance = Double.infinity
        
        for entry in dataSet.entries {
            let distance = abs(entry.x - targetX)
            if distance < closestDistance {
                closestDistance = distance
                closestEntry = entry
            }
        }
        
        let tolerance = usesTimestamps ? 7200.0 : 1.0 // 2 hours for timestamps, 1 unit for indices
        if let entry = closestEntry, closestDistance <= tolerance {
            print("🎯 Fallback: Retrieved \(String(format: "%.2f", entry.y)) for target index \(index) (actual x: \(entry.x), distance: \(String(format: "%.1f", closestDistance)), uses timestamps: \(usesTimestamps)) from dataset with \(dataSet.entries.count) entries")
            return entry.y
        }
        
        print("⚠️ No matching entry found for index \(index) in dataset with \(dataSet.entries.count) entries (uses timestamps: \(usesTimestamps))")
        return nil
    }
    
    /// Checks if the indicator line is actually visible/drawn at the given index
    private func isIndicatorVisibleAtIndex(_ index: Int, in dataSet: LineChartDataSet) -> Bool {
        guard !dataSet.entries.isEmpty else { return false }
        
        // Find the first index where the indicator actually has data
        guard let firstValidIndex = getFirstValidIndicatorIndex(from: dataSet) else { return false }
        
        // The indicator is only visible from its first valid data point onwards
        return index >= firstValidIndex
    }
    
    /// Gets the first index where the indicator has valid data (accounts for warm-up period)
    private func getFirstValidIndicatorIndex(from dataSet: LineChartDataSet) -> Int? {
        guard !dataSet.entries.isEmpty else { return nil }
        
        // For SMA/EMA datasets created with X values as timestamps,
        // find the first entry's X value and convert it to an index
        let firstEntry = dataSet.entries.first!
        
        // If X values are timestamps, we need to find the corresponding index
        // If X values are direct indices, we can use them directly
        let firstX = firstEntry.x
        
        // Check if X values appear to be timestamps (large numbers) or indices (small numbers)
        if firstX > 10000 { // Likely timestamp
            // For timestamp-based X values, we need a different approach
            // The warm-up period means SMA(20) starts at index 19, etc.
            // We can infer this from the dataset label
            if let label = dataSet.label {
                if label.contains("SMA") {
                    // Extract period from label like "SMA(20)"
                    let period = extractPeriodFromLabel(label) ?? 20
                    return period - 1  // SMA(20) starts at index 19
                } else if label.contains("EMA") {
                    // Extract period from label like "EMA(12)"
                    let period = extractPeriodFromLabel(label) ?? 12
                    return period - 1  // EMA(12) starts at index 11
                }
            }
            return 19 // Default warm-up for typical 20-period indicators
        } else {
            // X values are likely indices, use directly
            return Int(firstX)
        }
    }
    
    /// Extracts the period number from indicator labels like "SMA(20)" or "EMA(12)"
    private func extractPeriodFromLabel(_ label: String) -> Int? {
        // Simple string parsing approach - more reliable than regex for this case
        guard let startIndex = label.firstIndex(of: "("),
              let endIndex = label.firstIndex(of: ")"),
              startIndex < endIndex else {
            return nil
        }
        
        let numberString = String(label[label.index(after: startIndex)..<endIndex])
        return Int(numberString)
    }
    
    /// Gets the warmup period from dataset label (period - 1)
    private func getWarmupPeriodFromLabel(_ label: String?) -> Int {
        guard let label = label else { return 19 } // Default for typical 20-period indicators
        
        if let period = extractPeriodFromLabel(label) {
            return period - 1 // SMA(20) needs 19 warmup periods, starts at index 19
        }
        
        return 19 // Default warmup period
    }
    
    /// Gets RSI value at specific index
    private func getRSIValueAtIndex(_ index: Int, from rsiResult: TechnicalIndicators.RSIResult) -> Double? {
        guard index >= 0 && index < rsiResult.values.count else { 
            print("⚠️ RSI index \(index) out of bounds for RSI with \(rsiResult.values.count) values")
            return nil 
        }
        let value = rsiResult.values[index]
        let formattedValue = value.map { String(format: "%.2f", $0) } ?? "nil"
        print("🎯 RSI: Retrieved \(formattedValue) at index \(index) from RSI with \(rsiResult.values.count) values")
        return value
    }
    
    // MARK: - Private Helpers
    
    /// Formats currency values with adaptive precision so micro-prices don't collapse to $0.00
    private func formatCurrency(_ value: Double) -> String {
        if value >= 1 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.locale = Locale(identifier: "en_US")
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
        } else if value > 0 {
            var decimals = 6
            var v = value
            while v < 1 && v > 0 && decimals < 10 {
                v *= 10
                if v >= 1 { break }
                decimals += 1
            }
            let clamped = max(4, min(decimals, 10))
            return String(format: "$%.*f", clamped, value)
        } else {
            return "$0"
        }
    }
    
    /// Legacy abbreviated formatter (kept for compatibility)
    private func formatCurrencyAbbreviated(_ value: Double) -> String {
        if value >= 1000000 {
            return String(format: "$%.1fM", value / 1000000)
        } else if value >= 1000 {
            return String(format: "$%.1fK", value / 1000)
        } else if value >= 1 {
            return String(format: "$%.0f", value)
        } else {
            return String(format: "$%.4f", value)
        }
    }
}

// MARK: - Extensions for Chart Integration

extension ChartLabelManager {
    
    /// Updates all labels based on current chart data and settings
    func updateAllLabels(
        smaDataSet: LineChartDataSet?,
        emaDataSet: LineChartDataSet?, 
        rsiResult: TechnicalIndicators.RSIResult?,
        settings: TechnicalIndicators.IndicatorSettings,
        theme: ChartColorTheme,
        rsiAreaTop: CGFloat? = nil,
        rsiAreaHeight: CGFloat? = nil,
        dataPointCount: Int = 0
    ) {
        // Update SMA label
        let smaValue = getLatestSMAValue(from: smaDataSet)
        let smaColor = TechnicalIndicators.getIndicatorColor(for: "sma", theme: theme)
        updateSMALabel(value: smaValue, period: settings.smaPeriod, color: smaColor, isVisible: settings.showSMA, dataCount: dataPointCount)
        
        // Update EMA label
        let emaValue = getLatestEMAValue(from: emaDataSet)
        let emaColor = TechnicalIndicators.getIndicatorColor(for: "ema", theme: theme)
        updateEMALabel(value: emaValue, period: settings.emaPeriod, color: emaColor, isVisible: settings.showEMA, dataCount: dataPointCount)
        
        // Update RSI label
        let rsiValue = rsiResult != nil ? getLatestRSIValue(from: rsiResult!) : nil
        updateRSILabel(value: rsiValue, period: settings.rsiPeriod, isVisible: settings.showRSI, dataCount: dataPointCount)
        
        // Position RSI label in RSI section if coordinates provided
        if let rsiTop = rsiAreaTop, let rsiHeight = rsiAreaHeight, settings.showRSI {
            guard let parentChart = parentChart else { return }
            positionRSILabel(in: parentChart.bounds, rsiAreaTop: rsiTop, rsiAreaHeight: rsiHeight)
        }
    }
    
    /// Hides all technical indicator labels (used when switching to line charts)
    func hideAllTechnicalIndicatorLabels() {
        smaLabel?.isHidden = true
        emaLabel?.isHidden = true
        rsiLabel?.isHidden = true
    }
}
