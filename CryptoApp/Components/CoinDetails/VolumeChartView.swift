//
//  VolumeChartView.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
//

import UIKit
import DGCharts

final class VolumeChartView: BarChartView {
    
    // MARK: - Properties
    
    private var volumes: [Double] = []
    private var priceChanges: [Bool] = [] // true for bullish, false for bearish
    private var dates: [Date] = []
    private var currentRange: String = "24h"
    private var volumeAnalysis: TechnicalIndicators.VolumeAnalysis?
    
    // Settings
    private var showVolumeMA: Bool = false
    private var volumeMAPeriod: Int = 20
    private var currentTheme: ChartColorTheme = .classic
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    // MARK: - Configuration
    
    private func configure() {
        // Basic chart settings
        backgroundColor = .systemBackground
        legend.enabled = false
        dragEnabled = false
        setScaleEnabled(false)
        pinchZoomEnabled = false
        doubleTapToZoomEnabled = false
        highlightPerTapEnabled = false
        
        // Configure axes
        configureAxes()
        
        // Set minimal chart offsets to maximize volume display area
        setViewPortOffsets(left: 20, top: 5, right: 70, bottom: 5)
    }
    
    private func configureAxes() {
        // Left axis - disabled
        leftAxis.enabled = false
        
        // Right axis - Volume values
        rightAxis.enabled = true
        rightAxis.labelTextColor = .tertiaryLabel
        rightAxis.labelFont = .systemFont(ofSize: 9)
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawAxisLineEnabled = false
        rightAxis.valueFormatter = VolumeFormatter()
        rightAxis.labelCount = 3
        rightAxis.minWidth = 60
        rightAxis.forceLabelsEnabled = true
        
        // X axis - Hidden for volume (synchronized with main chart)
        xAxis.enabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
    }
    
    // MARK: - Public Update Methods
    
    func updateVolume(ohlcData: [OHLCData], range: String, theme: ChartColorTheme = .classic) {
        guard !ohlcData.isEmpty else { return }
        
        self.currentRange = range
        self.currentTheme = theme
        self.dates = ohlcData.map { $0.timestamp }
        
        // Extract volume data
        self.volumes = ohlcData.map { $0.volume ?? 0.0 }
        
        // Determine bullish/bearish for each period
        self.priceChanges = ohlcData.map { $0.isBullish }
        
        // Calculate volume analysis
        self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes, period: volumeMAPeriod)
        
        updateChart()
    }
    
    func updateSettings(showVolumeMA: Bool, volumeMAPeriod: Int) {
        self.showVolumeMA = showVolumeMA
        self.volumeMAPeriod = volumeMAPeriod
        
        // Recalculate volume analysis with new period
        if !volumes.isEmpty {
            self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes, period: volumeMAPeriod)
            updateChart()
        }
    }
    
    func applyColorTheme(_ theme: ChartColorTheme) {
        self.currentTheme = theme
        updateChart()
    }
    
    // MARK: - Chart Rendering
    
    private func updateChart() {
        guard !volumes.isEmpty else { return }
        
        let entries = volumes.enumerated().compactMap { index, volume -> BarChartDataEntry? in
            // SAFETY: Filter out NaN or invalid volume values
            guard volume.isFinite && volume >= 0 else { return nil }
            return BarChartDataEntry(x: Double(index), y: volume)
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "Volume")
        dataSet.drawValuesEnabled = false
        dataSet.drawIconsEnabled = false
        
        // Apply colors based on price movement
        var colors: [UIColor] = []
        for i in 0..<priceChanges.count {
            let baseColor = priceChanges[i] ? currentTheme.positiveColor : currentTheme.negativeColor
            
            // Highlight high volume periods
            if let analysis = volumeAnalysis, i < analysis.isHighVolume.count && analysis.isHighVolume[i] {
                colors.append(baseColor.withAlphaComponent(0.9)) // More opaque for high volume
            } else {
                colors.append(baseColor.withAlphaComponent(0.6)) // More transparent for normal volume
            }
        }
        dataSet.colors = colors
        
        let chartData = BarChartData(dataSet: dataSet)
        chartData.barWidth = 0.8 // Adjust bar width for better visibility
        self.data = chartData
        
        // Add volume moving average if enabled
        if showVolumeMA {
            addVolumeMovingAverage()
        }
        
        // Configure Y-axis range
        configureYAxisRange()
        
        notifyDataSetChanged()
    }
    
    private func addVolumeMovingAverage() {
        // Note: Volume moving average overlay would require CombinedChartView
        // For now, volume MA is calculated but not displayed on the chart
        // This is a placeholder for future enhancement when converting to CombinedChartView
        
        // The volume analysis already contains the MA data, available via:
        // volumeAnalysis?.volumeMA for external use
    }
    
    private func configureYAxisRange() {
        guard !volumes.isEmpty else { return }
        
        let maxVolume = volumes.max() ?? 0
        let minVolume = volumes.min() ?? 0
        
        // Add padding to show the highest volume bars clearly
        rightAxis.axisMinimum = 0
        rightAxis.axisMaximum = maxVolume * 1.1
        
        // Ensure we show at least some range even for very small volumes
        if maxVolume - minVolume < maxVolume * 0.1 {
            rightAxis.axisMaximum = maxVolume * 1.5
        }
    }
    
    // MARK: - Synchronization with Main Chart
    
    func synchronizeXAxisWith(chartView: ChartViewBase) {
        // Sync the visible X range with the main chart
        if let mainChart = chartView as? LineChartView {
            let visibleRange = mainChart.highestVisibleX - mainChart.lowestVisibleX
            setVisibleXRangeMinimum(visibleRange)
            setVisibleXRangeMaximum(visibleRange)
            moveViewToX(mainChart.lowestVisibleX + visibleRange / 2)
        } else if let mainChart = chartView as? CandleStickChartView {
            let visibleRange = mainChart.highestVisibleX - mainChart.lowestVisibleX
            setVisibleXRangeMinimum(visibleRange)
            setVisibleXRangeMaximum(visibleRange)
            moveViewToX(mainChart.lowestVisibleX + visibleRange / 2)
        }
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure chart redraws properly on orientation changes
        notifyDataSetChanged()
    }
    
    // MARK: - Dark Mode Support
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            backgroundColor = .systemBackground
            updateChart() // Refresh colors for new appearance
        }
    }
}

// MARK: - Volume Formatter

private class VolumeFormatter: AxisValueFormatter {
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return value.abbreviatedString()
    }
}

// MARK: - Extension for Volume Chart in Combined View

extension VolumeChartView {
    
    /// Creates a height constraint appropriate for volume display (typically 20-25% of main chart height)
    func recommendedHeightConstraint(relativeTo mainChartHeight: CGFloat) -> NSLayoutConstraint {
        let volumeHeight = mainChartHeight * 0.22 // 22% of main chart height
        return heightAnchor.constraint(equalToConstant: volumeHeight)
    }
    
    /// Returns whether the volume at the given index is considered high volume
    func isHighVolumeAt(index: Int) -> Bool {
        guard let analysis = volumeAnalysis,
              index < analysis.isHighVolume.count else { return false }
        return analysis.isHighVolume[index]
    }
    
    /// Returns the volume ratio (current/average) at the given index
    func volumeRatioAt(index: Int) -> Double {
        guard let analysis = volumeAnalysis,
              index < analysis.volumeRatio.count else { return 1.0 }
        return analysis.volumeRatio[index]
    }
}