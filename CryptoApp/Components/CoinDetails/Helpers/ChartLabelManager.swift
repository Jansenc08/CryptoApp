//
//  ChartLabelManager.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
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
                // Show intelligent message for insufficient data
                smaLabel.text = getInsufficientDataMessage(for: "SMA", period: period, availableDataCount: dataCount)
                smaLabel.textColor = UIColor.systemGray2
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
                // Show intelligent message for insufficient data
                emaLabel.text = getInsufficientDataMessage(for: "EMA", period: period, availableDataCount: dataCount)
                emaLabel.textColor = UIColor.systemGray2
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
        // we need to find the corresponding entry by matching x values (timestamps)
        
        guard !dataSet.entries.isEmpty else { 
            print("⚠️ Dataset is empty")
            return nil 
        }
        
        // If index is within bounds, use direct indexing
        if index >= 0 && index < dataSet.entries.count {
            let entry = dataSet.entries[index]
            let value = entry.y
            print("🎯 Direct: Retrieved \(String(format: "%.2f", value)) at index \(index) (x: \(entry.x)) from dataset with \(dataSet.entries.count) entries")
            return value
        }
        
        // Otherwise, find the entry with the closest x value to the target index
        let targetX = Double(index)
        var closestEntry: ChartDataEntry?
        var closestDistance = Double.infinity
        
        for entry in dataSet.entries {
            let distance = abs(entry.x - targetX)
            if distance < closestDistance {
                closestDistance = distance
                closestEntry = entry
            }
        }
        
        if let entry = closestEntry, closestDistance <= 1.0 { // Allow 1 unit tolerance
            print("🎯 Matched: Retrieved \(String(format: "%.2f", entry.y)) for target index \(index) (actual x: \(entry.x), distance: \(String(format: "%.1f", closestDistance))) from dataset with \(dataSet.entries.count) entries")
            return entry.y
        }
        
        print("⚠️ No matching entry found for index \(index) in dataset with \(dataSet.entries.count) entries")
        return nil
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