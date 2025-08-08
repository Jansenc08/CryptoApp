//
//  VolumeChartView.swift
//  CryptoApp
//
//  Created by Assistant on 1/30/25.
//

import UIKit
import DGCharts

/**
 * Volume Chart Component for Cryptocurrency Trading
 *
 * This class creates and manages volume bar charts that display trading volume data
 * synchronized with the main price chart. It provides visual representation of market
 * activity with color-coded bars indicating bullish/bearish periods.
 *
 * Key Features:
 * - Color-coded volume bars (green for bullish, red for bearish periods)
 * - High volume detection with enhanced transparency
 * - Synchronized X-axis with main chart for consistent time display
 * - Dynamic Y-axis scaling based on volume range
 * - Theme support for different color schemes
 * - Memory-efficient bar rendering using DGCharts
 *
 * Visual Design:
 * - Typically positioned below the main price chart
 * - Takes ~22% of main chart height for proportional display
 * - Seamless integration with borderless, clean appearance
 * - Right-axis labels showing volume values (formatted: K, M, B)
 *
 * Usage:
 * ```swift
 * volumeChart.updateVolume(ohlcData: data, range: "24h", theme: .classic)
 * volumeChart.synchronizeXAxisWith(chartView: mainChart)
 * ```
 */
final class VolumeChartView: BarChartView {
    
    // MARK: - Core Data Properties
    
    /// Raw volume values extracted from OHLC data (number of shares/tokens traded)
    private var volumes: [Double] = []
    
    /// Bullish/bearish indicator for each period (true = price went up, false = price went down)
    /// Used to determine bar colors: green for bullish, red for bearish periods
    private var priceChanges: [Bool] = []
    
    /// Timestamps corresponding to each volume data point for synchronization
    private var dates: [Date] = []
    
    /// Current time range being displayed ("24h", "7d", "30d", "All")
    /// Affects how volume analysis and scaling is performed
    private var currentRange: String = "24h"
    
    /// Technical analysis of volume patterns including high/low volume detection
    /// Provides volume ratios and identifies significant volume spikes
    private var volumeAnalysis: TechnicalIndicators.VolumeAnalysis?
    
    // MARK: - Display Settings
    
    /// Current color theme for consistent appearance across chart components
    /// Determines colors for bullish/bearish bars and overall styling
    private var currentTheme: ChartColorTheme = .classic
    

    
    // MARK: - Initialization
    
    /**
     * Programmatic initialization
     * Sets up the volume chart with default configuration for trading volume display
     */
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    /**
     * Storyboard/XIB initialization
     * Ensures consistent setup regardless of creation method
     */
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    // MARK: - Configuration
    
    /**
     * Configures the volume chart for optimal trading volume display
     * 
     * Sets up professional appearance with:
     * - Transparent background for seamless integration
     * - Disabled user interactions (synchronized with main chart)
     * - Clean, borderless design
     * - Proper axis configuration for volume display
     */
    private func configure() {
        // MARK: Professional Chart Appearance
        backgroundColor = .clear                    // Transparent background for seamless integration
        legend.enabled = false                      // No legend needed (volume is self-explanatory)
        
        // MARK: Disable User Interactions (Volume chart is read-only, synchronized with main chart)
        dragEnabled = false                         // No dragging - main chart controls navigation
        setScaleEnabled(false)                      // No zooming - maintains synchronization
        pinchZoomEnabled = false                    // No pinch gestures
        doubleTapToZoomEnabled = false             // No double-tap zoom
        highlightPerTapEnabled = false             // No touch highlighting
        
        // MARK: Visual Design
        // Clean, borderless design for seamless integration with main chart
        layer.borderWidth = 0                       // No borders for clean appearance
        layer.cornerRadius = 0                      // Square corners to match main chart
        
        // MARK: Setup Chart Components
        configureAxes()                             // Configure X and Y axes for volume display
        
        // MARK: Layout Offsets
        // Add padding to prevent Y-axis label clipping and ensure proper spacing
        setViewPortOffsets(
            left: 20,      // Space for potential left labels
            top: 20,       // Top padding to prevent clipping
            right: 70,     // Space for volume value labels (e.g., "1.2M", "500K")
            bottom: 16     // Bottom padding for clean appearance
        )
    }
    
    /**
     * Configures X and Y axes for optimal volume chart display
     * 
     * Design Philosophy:
     * - Y-axis shows volume values (right side) with clean formatting
     * - X-axis is hidden to maintain synchronization with main chart
     * - No grid lines for clean, minimal appearance
     */
    private func configureAxes() {
        // MARK: Left Axis Configuration
        leftAxis.enabled = false                    // Disable left axis (not used in volume charts)
        
        // MARK: Right Axis Configuration (Volume Values Display)
        rightAxis.enabled = true                    // Enable right axis for volume values
        rightAxis.labelTextColor = .label // Better visibility in dark mode
        rightAxis.labelFont = .systemFont(ofSize: 11, weight: .medium)  // Readable font size
        rightAxis.drawGridLinesEnabled = false     // No grid lines for clean appearance
        rightAxis.drawAxisLineEnabled = false      // No axis line for seamless design
        rightAxis.valueFormatter = VolumeFormatter() // Format values as "1.2M", "500K", etc.
        rightAxis.labelCount = 3                   // Show 3 labels (min, mid, max volume)
        rightAxis.minWidth = 40                    // Reserve space for volume labels
        rightAxis.forceLabelsEnabled = true        // Always show labels even in small spaces
        
        // MARK: Axis Spacing (Prevent Label Clipping)
        rightAxis.spaceTop = 0.1                   // 10% padding at top
        rightAxis.spaceBottom = 0.1                // 10% padding at bottom
        
        // MARK: X-Axis Configuration (Hidden for Synchronization)
        // X-axis is managed by the main chart to maintain perfect alignment
        xAxis.enabled = false                       // Hide X-axis labels
        xAxis.drawGridLinesEnabled = false         // No vertical grid lines
        xAxis.drawAxisLineEnabled = false          // No axis line
    }
    
    // MARK: - Public Update Methods
    
    /**
     * Updates the volume chart with new OHLC data
     * 
     * This is the main entry point for updating volume display. It processes
     * OHLC data to extract volume information and price movement direction.
     * 
     * - Parameters:
     *   - ohlcData: Array of OHLC data containing volume and price information
     *   - range: Time range string ("24h", "7d", "30d", "All") affecting analysis
     *   - theme: Color theme for consistent appearance across chart components
     * 
     * Process Flow:
     * 1. Validate input data
     * 2. Extract volume values and price movement direction
     * 3. Perform volume analysis (high/low volume detection)
     * 4. Trigger chart rendering with color-coded bars
     */
    func updateVolume(ohlcData: [OHLCData], range: String, theme: ChartColorTheme = .classic) {
        // MARK: Input Validation
        guard !ohlcData.isEmpty else { 
            // Clear chart data if no volume data available
            let emptyData = BarChartData()
            self.data = emptyData
            return 
        }
        
        // MARK: Store Configuration
        self.currentRange = range                   // Store time range for analysis
        self.currentTheme = theme                   // Store theme for color consistency
        self.dates = ohlcData.map { $0.timestamp }  // Extract timestamps for synchronization
        
        // MARK: Extract Volume Data
        // Convert OHLC data to volume values, defaulting to 0 for missing volume
        self.volumes = ohlcData.map { $0.volume ?? 0.0 }
        
        // MARK: Determine Price Movement Direction
        // Extract bullish/bearish indicators for bar coloring
        // true = green bar (price went up), false = red bar (price went down)
        self.priceChanges = ohlcData.map { $0.isBullish }
        
        // MARK: Perform Volume Analysis
        // Calculate volume ratios, identify high volume periods, detect patterns
        self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes)
        
        // MARK: Trigger Chart Update
        updateChart()                               // Render the updated volume bars
    }
    
    /**
     * Recalculates volume analysis and refreshes chart display
     * 
     * Used when volume analysis settings change but the underlying data remains the same.
     * Useful for real-time updates or when technical indicator settings are modified.
     */
    func updateSettings() {
        // Recalculate volume analysis if we have data
        if !volumes.isEmpty {
            self.volumeAnalysis = TechnicalIndicators.analyzeVolume(volumes: volumes)
            updateChart()                           // Re-render with updated analysis
        }
    }
    
    /**
     * Applies a new color theme to the volume chart
     * 
     * Updates the chart appearance to match the selected theme while preserving
     * all volume data and analysis. Triggers immediate re-rendering.
     * 
     * - Parameter theme: New color theme to apply (.classic, .ocean, .monochrome, .accessibility)
     */
    func applyColorTheme(_ theme: ChartColorTheme) {
        self.currentTheme = theme                   // Store new theme
        updateChart()                               // Re-render with new colors
    }
    
    // MARK: - Chart Rendering
    
    /**
     * Core chart rendering method that creates volume bars from processed data
     * 
     * This method transforms raw volume data into visual bar chart entries with
     * intelligent color coding and transparency based on volume analysis.
     * 
     * Rendering Process:
     * 1. Create chart entries from volume data
     * 2. Apply color coding (green/red based on price movement)
     * 3. Apply transparency based on volume significance
     * 4. Configure chart display properties
     * 5. Force refresh for immediate visual update
     * 
     * Color Logic:
     * - Green bars: Bullish periods (price increased)
     * - Red bars: Bearish periods (price decreased)
     * - High transparency (0.9): High volume periods (significant activity)
     * - Low transparency (0.6): Normal volume periods
     */
    private func updateChart() {
        // MARK: Data Validation
        guard !volumes.isEmpty else { 
            // Clear chart if no volume data available
            let emptyData = BarChartData()
            self.data = emptyData
            return 
        }
        
        // MARK: Create Chart Entries
        // Transform volume data into chart-readable format
        let entries = volumes.enumerated().compactMap { index, volume -> BarChartDataEntry? in
            // SAFETY: Filter out invalid volume values while allowing zero volumes
            guard volume.isFinite && volume >= 0 else { return nil }
            
            // Use array indices for X-axis positioning (ensures consistent spacing)
            return BarChartDataEntry(x: Double(index), y: volume)
        }
        
        // MARK: Validate Entries
        guard !entries.isEmpty else {
            let emptyData = BarChartData()
            self.data = emptyData
            return
        }
        
        // MARK: Create Dataset
        let dataSet = BarChartDataSet(entries: entries, label: "Volume")
        dataSet.drawValuesEnabled = false          // Hide value labels on bars (clean appearance)
        dataSet.drawIconsEnabled = false           // No icons needed for volume bars
        
        // MARK: Apply Intelligent Color Coding
        var colors: [UIColor] = []
        for i in 0..<priceChanges.count {
            // Base color selection: green for bullish, red for bearish
            let baseColor = priceChanges[i] ? currentTheme.positiveColor : currentTheme.negativeColor
            
            // Apply transparency based on volume significance
            if let analysis = volumeAnalysis, i < analysis.isHighVolume.count && analysis.isHighVolume[i] {
                // High volume periods: More opaque (90% opacity) to draw attention
                colors.append(baseColor.withAlphaComponent(0.9))
            } else {
                // Normal volume periods: More transparent (60% opacity) for subtle display
                colors.append(baseColor.withAlphaComponent(0.6))
            }
        }
        dataSet.colors = colors
        
        // MARK: Create Chart Data
        let barData = BarChartData(dataSet: dataSet)
        barData.barWidth = 0.8                     // Optimal bar width for clean appearance
        
        // MARK: Apply Data to Chart
        self.data = barData
        
        // MARK: Force Chart Refresh
        self.notifyDataSetChanged()                // Notify DGCharts of data changes
        self.setNeedsDisplay()                     // Trigger visual redraw
        
        // MARK: Configure Display Range
        self.configureYAxisRange()                 // Set appropriate Y-axis scaling
        
        // MARK: Final Update
        self.notifyDataSetChanged()                // Double notification for reliability
        
        // MARK: Ensure Visibility
        self.isHidden = false                      // Make chart visible
        self.alpha = 1.0                          // Full opacity
    }

    /**
     * Configures Y-axis range for optimal volume visualization
     * 
     * Automatically scales the Y-axis to show volume data clearly with appropriate
     * padding. Handles edge cases like very small volume ranges or zero volumes.
     * 
     * Scaling Logic:
     * - Always starts from 0 (volume can't be negative)
     * - Adds 10% padding above maximum volume for visual clarity
     * - For narrow ranges, expands to 50% padding to prevent cramped display
     * - Forces axis refresh to apply new ranges immediately
     */
    private func configureYAxisRange() {
        guard !volumes.isEmpty else { return }
        
        // MARK: Calculate Volume Range
        let maxVolume = volumes.max() ?? 0          // Highest volume in dataset
        let minVolume = volumes.min() ?? 0          // Lowest volume (usually 0)
        
        // MARK: Set Base Range
        rightAxis.axisMinimum = 0                   // Volume always starts from 0
        rightAxis.axisMaximum = maxVolume * 1.1     // Add 10% padding above max
        
        // MARK: Handle Narrow Ranges
        // If volume range is very narrow, expand padding for better visibility
        if maxVolume - minVolume < maxVolume * 0.1 {
            rightAxis.axisMaximum = maxVolume * 1.5 // Increase to 50% padding
        }
        
        // MARK: Apply Range Changes
        // Force the axis to refresh its calculations and redraw labels
        rightAxis.resetCustomAxisMin()
        rightAxis.resetCustomAxisMax()
    }
    
    // MARK: - Synchronization with Main Chart
    
    /**
     * Synchronizes the volume chart X-axis with the main price chart
     * 
     * Unlike the main chart which can zoom and pan, the volume chart always shows
     * the complete dataset for full context. This provides a consistent overview
     * of trading activity across the entire time period.
     * 
     * Synchronization Approach:
     * - Shows ALL volume bars regardless of main chart zoom level
     * - Maintains consistent spacing with main chart time periods
     * - Centers view to display complete dataset
     * - Fits all data on screen for comprehensive overview
     * 
     * - Parameter chartView: The main chart to synchronize with (for future enhancements)
     */
    func synchronizeXAxisWith(chartView: ChartViewBase) {
        guard !volumes.isEmpty else { return }
        
        // MARK: Calculate Full Range
        let fullRange = Double(volumes.count - 1)   // Index range from 0 to count-1
        
        // MARK: Set Visible Range
        // Force volume chart to show ALL data points (no zooming)
        setVisibleXRangeMinimum(fullRange)          // Minimum range = full dataset
        setVisibleXRangeMaximum(fullRange)          // Maximum range = full dataset
        
        // MARK: Center View
        moveViewToX(fullRange / 2)                  // Center on middle of dataset
        
        // MARK: Optimize Display
        fitScreen()                                 // Ensure all bars fit properly
    }
    
    // MARK: - Layout Management
    
    /**
     * Handles layout updates during device rotation or size changes
     * 
     * Ensures the volume chart renders correctly when the device orientation
     * changes or when the view bounds are modified. Forces a data refresh
     * to prevent visual artifacts during transitions.
     */
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure chart redraws properly after layout changes
        notifyDataSetChanged()                      // Refresh chart data visualization
    }
    
    // MARK: - Dark Mode Support
    
    /**
     * Responds to iOS appearance changes (Light/Dark mode transitions)
     * 
     * Automatically updates the volume chart appearance when the user switches
     * between light and dark modes. Refreshes colors and background to maintain
     * visual consistency with the system theme.
     * 
     * - Parameter previousTraitCollection: Previous trait collection for comparison
     */
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Check if the color appearance actually changed (light <-> dark mode)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            backgroundColor = .systemBackground       // Update background for new mode
            updateChart()                            // Refresh all colors for new appearance
        }
    }
}

// MARK: - Extension for Volume Chart in Combined View

/**
 * Extension providing utility methods for volume chart integration and analysis
 * 
 * These methods support integration with main chart components and provide
 * access to volume analysis data for external components that need volume
 * information (tooltips, crosshairs, detailed analysis views).
 */
extension VolumeChartView {
    
    /**
     * Creates an appropriate height constraint for volume chart display
     * 
     * Calculates the recommended height for the volume chart as a percentage
     * of the main chart height. This ensures proper proportional display
     * where volume doesn't overwhelm the price data but remains clearly visible.
     * 
     * - Parameter mainChartHeight: Height of the main price chart
     * - Returns: NSLayoutConstraint with calculated height (22% of main chart)
     * 
     * Design Rationale:
     * - 22% provides good balance between visibility and main chart prominence
     * - Follows financial charting conventions (volume typically 20-25% of total)
     * - Allows clear volume pattern recognition without dominating the display
     */
    func recommendedHeightConstraint(relativeTo mainChartHeight: CGFloat) -> NSLayoutConstraint {
        let volumeHeight = mainChartHeight * 0.22   // 22% of main chart height
        return heightAnchor.constraint(equalToConstant: volumeHeight)
    }
    
    /**
     * Determines if volume at a specific index represents high trading activity
     * 
     * Uses volume analysis results to identify periods of significantly elevated
     * trading activity. Useful for highlighting important market events,
     * breakouts, or periods of high investor interest.
     * 
     * - Parameter index: Data point index to check
     * - Returns: true if volume is considered high, false otherwise
     * 
     * High Volume Criteria:
     * - Volume significantly above recent average (typically 1.5x or more)
     * - Calculated by TechnicalIndicators.analyzeVolume() method
     * - Considers rolling average to account for natural volume fluctuations
     */
    func isHighVolumeAt(index: Int) -> Bool {
        guard let analysis = volumeAnalysis,
              index < analysis.isHighVolume.count else { return false }
        return analysis.isHighVolume[index]
    }
    
    /**
     * Gets the volume ratio (current volume / average volume) at a specific index
     * 
     * Provides quantitative measure of how current volume compares to recent
     * average. Values > 1.0 indicate above-average volume, values < 1.0 indicate
     * below-average volume.
     * 
     * - Parameter index: Data point index to analyze
     * - Returns: Volume ratio (1.0 = average volume, 2.0 = double average, etc.)
     * 
     * Usage Examples:
     * - 1.0: Normal volume (at recent average)
     * - 1.5: 50% above average (elevated interest)
     * - 2.0: Double average volume (significant activity)
     * - 0.5: Half average volume (low activity)
     */
    func volumeRatioAt(index: Int) -> Double {
        guard let analysis = volumeAnalysis,
              index < analysis.volumeRatio.count else { return 1.0 }
        return analysis.volumeRatio[index]
    }
}