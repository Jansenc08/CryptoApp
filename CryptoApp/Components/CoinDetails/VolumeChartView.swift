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
        // Professional volume chart appearance
        backgroundColor = .clear
        legend.enabled = false
        dragEnabled = false
        setScaleEnabled(false)
        pinchZoomEnabled = false
        doubleTapToZoomEnabled = false
        highlightPerTapEnabled = false
        
        // Configure for BarChartView (volume bars only)
        // Note: drawOrder is not needed for BarChartView as it only displays bars
        
        // Clean, borderless design for seamless integration
        layer.borderWidth = 0
        layer.cornerRadius = 0
        
        // Configure axes
        configureAxes()
        
        // Add top padding to prevent Y-axis label clipping
        setViewPortOffsets(left: 20, top: 20, right: 70, bottom: 16)
    }
    
    private func configureAxes() {
        // Left axis - disabled
        leftAxis.enabled = false
        
        // Right axis - Volume values with maximum visibility
        rightAxis.enabled = true
        rightAxis.labelTextColor = .secondaryLabel  // Match main chart's grey labels
        rightAxis.labelFont = .systemFont(ofSize: 11, weight: .medium)  // Larger, bold font
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawAxisLineEnabled = false
        rightAxis.valueFormatter = VolumeFormatter()
        rightAxis.labelCount = 3  // More labels for better context
        rightAxis.minWidth = 40   // Normal width
        rightAxis.forceLabelsEnabled = true
        rightAxis.spaceTop = 0.1  // Add space at top to prevent clipping
        rightAxis.spaceBottom = 0.1  // Add space at bottom to prevent clipping
        
        // X axis - Hidden for volume (synchronized with main chart)
        xAxis.enabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
    }
    
    // MARK: - Public Update Methods
    
    func updateVolume(ohlcData: [OHLCData], range: String, theme: ChartColorTheme = .classic) {
        guard !ohlcData.isEmpty else { 
            // Clear chart data if no volume data
            let emptyData = BarChartData()
            self.data = emptyData
            return 
        }
        

        
        self.currentRange = range
        self.currentTheme = theme
        self.dates = ohlcData.map { $0.timestamp }
        
        // Extract volume data
        self.volumes = ohlcData.map { $0.volume ?? 0.0 }
        
        // Determine bullish/bearish for each period
        self.priceChanges = ohlcData.map { $0.isBullish }
        
        // Calculate volume analysis
        self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes)
        
        // Update chart immediately
        updateChart()
    }
    
    func updateSettings() {
        // Recalculate volume analysis if needed
        if !volumes.isEmpty {
            self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes)
            updateChart()
        }
    }
    
    func applyColorTheme(_ theme: ChartColorTheme) {
        self.currentTheme = theme
        updateChart()
    }
    
    // MARK: - Chart Rendering
    
    private func updateChart() {
        guard !volumes.isEmpty else { 
            // Clear chart if no data
            let emptyData = BarChartData()
            self.data = emptyData
            return 
        }
        
        let entries = volumes.enumerated().compactMap { index, volume -> BarChartDataEntry? in
            // SAFETY: Filter out NaN or invalid volume values, but allow zero values for visualization
            guard volume.isFinite && volume >= 0 else { return nil }
            
            // Use array indices for consistent spacing
            return BarChartDataEntry(x: Double(index), y: volume)
        }
        
        guard !entries.isEmpty else {
            let emptyData = BarChartData()
            self.data = emptyData
            return
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "Volume")
        dataSet.drawValuesEnabled = false
        dataSet.drawIconsEnabled = false
        
        // Apply colors based on price movement with elegant transparency
        var colors: [UIColor] = []
        for i in 0..<priceChanges.count {
            let baseColor = priceChanges[i] ? currentTheme.positiveColor : currentTheme.negativeColor
            
            // Refined transparency for elegant appearance
            if let analysis = volumeAnalysis, i < analysis.isHighVolume.count && analysis.isHighVolume[i] {
                colors.append(baseColor.withAlphaComponent(0.9)) // Slightly transparent for high volume
            } else {
                colors.append(baseColor.withAlphaComponent(0.6)) // More transparent for normal volume
            }
        }
        dataSet.colors = colors
        
        // Create chart data for volume bars only
        let barData = BarChartData(dataSet: dataSet)
        barData.barWidth = 0.8 // Optimized bar width for clean appearance
        
        // Store chart data
        self.data = barData
        
        // Force chart refresh to ensure Y-axis labels are displayed
        self.notifyDataSetChanged()
        self.setNeedsDisplay()
        
        // Configure Y-axis range
        self.configureYAxisRange()
        
        // Force chart update 
        self.notifyDataSetChanged()
        
        // Ensure the chart view knows it has content
        self.isHidden = false
        self.alpha = 1.0
        

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
        
        // Force the right axis to refresh its calculations
        rightAxis.resetCustomAxisMin()
        rightAxis.resetCustomAxisMax()
    }
    
    // MARK: - Synchronization with Main Chart
    
    func synchronizeXAxisWith(chartView: ChartViewBase) {
        // Volume chart should show ALL bars across the full width, not zoom like main chart
        guard !volumes.isEmpty else { return }
        
        // Show all data points (from 0 to volumes.count-1)
        let fullRange = Double(volumes.count - 1)
        setVisibleXRangeMinimum(fullRange)
        setVisibleXRangeMaximum(fullRange)
        
        // Center the view to show all data
        moveViewToX(fullRange / 2)
        
        // Fit all bars on screen
        fitScreen()
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