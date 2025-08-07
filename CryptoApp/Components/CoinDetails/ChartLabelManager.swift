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
    
    // MARK: - Initialization
    
    init(parentChart: UIView) {
        self.parentChart = parentChart
        setupLabelContainers()
    }
    
    // MARK: - Setup
    
    private func setupLabelContainers() {
        guard let parentChart = parentChart else { return }
        
        // Create top labels container for SMA/EMA values (similar to CoinMarketCap)
        topLabelsContainer = UIStackView()
        topLabelsContainer?.axis = .horizontal
        topLabelsContainer?.spacing = 16
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
        // SMA Label
        smaLabel = createTechnicalIndicatorLabel()
        smaLabel?.isHidden = true
        
        // EMA Label  
        emaLabel = createTechnicalIndicatorLabel()
        emaLabel?.isHidden = true
        
        // RSI Label (styled differently)
        rsiLabel = createRSILabel()
        rsiLabel?.isHidden = true
        
        // Add labels to containers
        if let topContainer = topLabelsContainer {
            if let smaLabel = smaLabel { topContainer.addArrangedSubview(smaLabel) }
            if let emaLabel = emaLabel { topContainer.addArrangedSubview(emaLabel) }
        }
        
        if let rsiContainer = rsiLabelContainer, let rsiLabel = rsiLabel {
            rsiContainer.addSubview(rsiLabel)
            NSLayoutConstraint.activate([
                rsiLabel.leadingAnchor.constraint(equalTo: rsiContainer.leadingAnchor, constant: 8),
                rsiLabel.centerYAnchor.constraint(equalTo: rsiContainer.centerYAnchor)
            ])
        }
    }
    
    private func createTechnicalIndicatorLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
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
    
    /// Updates SMA label with current value and settings
    func updateSMALabel(value: Double?, period: Int, color: UIColor, isVisible: Bool) {
        guard let smaLabel = smaLabel else { return }
        
        smaLabel.isHidden = !isVisible
        
        if isVisible, let value = value {
            let formattedValue = formatCurrency(value)
            smaLabel.text = "SMA(\(period)): \(formattedValue)"
            smaLabel.textColor = color
        }
    }
    
    /// Updates EMA label with current value and settings
    func updateEMALabel(value: Double?, period: Int, color: UIColor, isVisible: Bool) {
        guard let emaLabel = emaLabel else { return }
        
        emaLabel.isHidden = !isVisible
        
        if isVisible, let value = value {
            let formattedValue = formatCurrency(value)
            emaLabel.text = "EMA(\(period)): \(formattedValue)"
            emaLabel.textColor = color
        }
    }
    
    /// Updates RSI label with current value and settings
    func updateRSILabel(value: Double?, period: Int, isVisible: Bool) {
        guard let rsiLabel = rsiLabel else { return }
        
        rsiLabel.isHidden = !isVisible
        
        if isVisible, let value = value {
            let formattedValue = String(format: "%.2f", value)
            rsiLabel.text = "RSI(\(period)): \(formattedValue)"
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
    
    // MARK: - Private Helpers
    
    /// Formats currency values using the same logic as PriceFormatter
    private func formatCurrency(_ value: Double) -> String {
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
        rsiAreaHeight: CGFloat? = nil
    ) {
        // Update SMA label
        let smaValue = getLatestSMAValue(from: smaDataSet)
        let smaColor = TechnicalIndicators.getIndicatorColor(for: "sma", theme: theme)
        updateSMALabel(value: smaValue, period: settings.smaPeriod, color: smaColor, isVisible: settings.showSMA)
        
        // Update EMA label
        let emaValue = getLatestEMAValue(from: emaDataSet)
        let emaColor = TechnicalIndicators.getIndicatorColor(for: "ema", theme: theme)
        updateEMALabel(value: emaValue, period: settings.emaPeriod, color: emaColor, isVisible: settings.showEMA)
        
        // Update RSI label
        let rsiValue = rsiResult != nil ? getLatestRSIValue(from: rsiResult!) : nil
        updateRSILabel(value: rsiValue, period: settings.rsiPeriod, isVisible: settings.showRSI)
        
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