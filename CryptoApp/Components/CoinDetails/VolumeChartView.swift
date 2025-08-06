//
//  VolumeChartView.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
//

import UIKit
import DGCharts

final class VolumeChartView: CombinedChartView {
    
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
    
    // Prevent duplicate MA calls
    private var lastMAUpdateTimestamp: TimeInterval = 0
    
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
        
        // CRITICAL: Configure for CombinedChartView to support both bars and lines
        drawOrder = [DrawOrder.bar.rawValue, DrawOrder.line.rawValue]
        
        // Ensure renderers are properly configured
        renderer = CombinedChartRenderer(chart: self, animator: chartAnimator, viewPortHandler: viewPortHandler)
        
        // Subtle border for visual separation
        layer.borderColor = UIColor.systemGray5.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 4
        
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
        guard !ohlcData.isEmpty else { 
            // Clear chart data if no volume data
            let emptyData = CombinedChartData()
            self.data = emptyData
            return 
        }
        

        
        self.currentRange = range
        self.currentTheme = theme
        self.dates = ohlcData.map { $0.timestamp }
        
        // Extract volume data
        self.volumes = ohlcData.map { $0.volume ?? 0.0 }
        let nonZeroVolumes = volumes.filter { $0 > 0 }.count
        
        // Determine bullish/bearish for each period
        self.priceChanges = ohlcData.map { $0.isBullish }
        
        // Calculate volume analysis
        self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes, period: volumeMAPeriod)
        
        // Update chart immediately
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
        guard !volumes.isEmpty else { 
            // Clear chart if no data
            let emptyData = CombinedChartData()
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
            let emptyData = CombinedChartData()
            self.data = emptyData
            return
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "Volume")
        dataSet.drawValuesEnabled = false
        dataSet.drawIconsEnabled = false
        
        // Apply colors based on price movement
        var colors: [UIColor] = []
        for i in 0..<priceChanges.count {
            let baseColor = priceChanges[i] ? currentTheme.positiveColor : currentTheme.negativeColor
            
            // Make volume bars much more visible
            if let analysis = volumeAnalysis, i < analysis.isHighVolume.count && analysis.isHighVolume[i] {
                colors.append(baseColor.withAlphaComponent(1.0)) // Fully opaque for high volume
            } else {
                colors.append(baseColor.withAlphaComponent(0.8)) // More opaque for normal volume
            }
        }
        dataSet.colors = colors
        
        // Create CombinedChartData to support both bars and moving average line
        let combinedData = CombinedChartData()
        let barData = BarChartData(dataSet: dataSet)
        barData.barWidth = 0.9 // Wider bars for better visibility
        combinedData.barData = barData
        
        // Store chart data directly - no async to prevent clearing by subsequent calls
        self.data = combinedData
        
        // Configure Y-axis range
        self.configureYAxisRange()
        
        // Add volume moving average if enabled
        if showVolumeMA {
            self.addVolumeMovingAverage()
        }
        
        // Force chart update 
        self.notifyDataSetChanged()
        
        // Ensure the chart view knows it has content
        self.isHidden = false
        self.alpha = 1.0
        

    }
    
    private func addVolumeMovingAverage() {
        // Prevent rapid duplicate calls
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastMAUpdateTimestamp < 0.1 {
            AppLogger.chart("🟠 Volume MA: Skipping duplicate call (too soon)")
            return
        }
        lastMAUpdateTimestamp = currentTime
        
        guard let analysis = volumeAnalysis,
              !analysis.volumeMA.isEmpty,
              let combinedData = self.data as? CombinedChartData else { 
            AppLogger.chart("🟠 Volume MA: Cannot add - no analysis data or chart data")
            return 
        }
        
        // Create line data entries for volume moving average using SAME indices as volume bars
        let maEntries = analysis.volumeMA.enumerated().compactMap { index, ma -> ChartDataEntry? in
            guard let ma = ma, ma.isFinite && ma >= 0,
                  index < volumes.count else { return nil }
            
            // Use the SAME array index as the corresponding volume bar for perfect alignment
            return ChartDataEntry(x: Double(index), y: ma)
        }
        
        guard !maEntries.isEmpty else { 
            AppLogger.chart("🟠 Volume MA: No valid MA entries to display")
            return 
        }
        
        AppLogger.chart("🟠 Volume MA: Adding \(maEntries.count) MA points with period \(volumeMAPeriod)")
        
        // Create EXTREMELY VISIBLE line data set for volume MA
        let maDataSet = LineChartDataSet(entries: maEntries, label: "Volume MA(\(volumeMAPeriod))")
        maDataSet.drawCirclesEnabled = true  
        maDataSet.circleRadius = 8.0 // HUGE circles
        maDataSet.circleHoleRadius = 4.0
        maDataSet.drawValuesEnabled = true // Show values for debugging
        maDataSet.lineWidth = 10.0 // EXTREMELY thick line
        maDataSet.setColor(.systemRed) // BRIGHT RED for absolute contrast against green/red bars
        maDataSet.setCircleColor(.systemRed)
        maDataSet.drawFilledEnabled = true 
        maDataSet.fillAlpha = 0.7 // More opaque fill
        maDataSet.fillColor = .systemRed
        maDataSet.mode = .linear 
        
        // Force line to appear on top
        maDataSet.highlightEnabled = false
        
        // Add line data to existing combined data (creates overlay effect)
        combinedData.lineData = LineChartData(dataSet: maDataSet)
        
        // Debug: Check what data we actually have
        AppLogger.chart("🟠 DEBUG: CombinedData has \(combinedData.barData?.dataSetCount ?? 0) bar datasets and \(combinedData.lineData?.dataSetCount ?? 0) line datasets")
        AppLogger.chart("🟠 DEBUG: Line dataset has \(maDataSet.count) entries, color: \(maDataSet.colors.first?.description ?? "nil")")
        AppLogger.chart("🟠 DEBUG: Bar data entry count: \(combinedData.barData?.entryCount ?? 0)")
        AppLogger.chart("🟠 DEBUG: Line data entry count: \(combinedData.lineData?.entryCount ?? 0)")
        
        // Debug X-axis ranges to verify alignment
        if let barDataSet = combinedData.barData?.dataSets.first as? BarChartDataSet {
            let barXRange = barDataSet.entries.map(\.x)
            AppLogger.chart("🟠 DEBUG: Bar X-axis range: \(barXRange.min() ?? 0) to \(barXRange.max() ?? 0)")
        }
        if let lineDataSet = combinedData.lineData?.dataSets.first as? LineChartDataSet {
            let lineXRange = lineDataSet.entries.map(\.x)
            AppLogger.chart("🟠 DEBUG: Line X-axis range: \(lineXRange.min() ?? 0) to \(lineXRange.max() ?? 0)")
        }
        
        // Force the chart to re-render with both data types
        self.data = combinedData
        self.notifyDataSetChanged()
        self.setNeedsDisplay()
        
        AppLogger.chart("🔴 Volume MA: Successfully added EXTREMELY THICK RED line with HUGE CIRCLES and HEAVY FILL using MATCHING INDICES to volume chart")
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