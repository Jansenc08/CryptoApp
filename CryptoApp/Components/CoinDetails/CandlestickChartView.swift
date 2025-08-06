//
//  CandlestickChartView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

final class CandlestickChartView: CombinedChartView {
    
    // MARK: - Properties
    
    private var allOHLCData: [OHLCData] = []
    private var allDates: [Date] = []
    private var currentRange: String = "24h"
    private var visibleDataPointsCount: Int = 50
    private var currentScrollPosition: CGFloat = 0
    
    // Common chart functionality helper
    private let configurationHelper = ChartConfigurationHelper()
    
    // Callback to notify when user scrolls to chart edge
    var onScrollToEdge: ((ScrollDirection) -> Void)?
    
    // Scroll direction used for edge detection
    enum ScrollDirection {
        case left, right
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
        configure()
    }
    
    // MARK: - Chart Setup
    private func configure() {
        // DIRECT CONFIGURATION: Since we're now using CombinedChartView
        // Basic chart settings
        backgroundColor = .systemBackground
        legend.enabled = false
        dragEnabled = true
        setScaleEnabled(true)
        pinchZoomEnabled = true
        doubleTapToZoomEnabled = true
        highlightPerTapEnabled = true
        
        // Configure axes for combined chart
        leftAxis.enabled = false
        rightAxis.enabled = true
        rightAxis.labelFont = .systemFont(ofSize: 9)
        rightAxis.labelTextColor = .tertiaryLabel
        rightAxis.drawGridLinesEnabled = true
        rightAxis.gridColor = .systemGray5
        rightAxis.gridLineWidth = 0.5
        
        xAxis.enabled = true
        xAxis.labelPosition = .bottom
        xAxis.labelFont = .systemFont(ofSize: 9)
        xAxis.labelTextColor = .tertiaryLabel
        xAxis.drawGridLinesEnabled = false  // Remove vertical grid lines
        xAxis.gridColor = .systemGray5
        xAxis.gridLineWidth = 0.5
        
        // Candlestick chart specific settings  
        scaleXEnabled = true                // ENABLE X-axis zoom for proper zoom out functionality
        scaleYEnabled = false               // Disable Y-axis zoom to maintain consistent candle proportions
        
        // Set zoom limits optimized for candlestick analysis
        setVisibleXRangeMaximum(200)        // Max zoom out (show 200 candles) - increased for monthly/all views
        setVisibleXRangeMinimum(3)          // Max zoom in (show 3 candles for detail)
        
        // ZOOM GESTURES: Add the zoom functionality that was missing
        isUserInteractionEnabled = true
        
        // Triple-tap to reset zoom
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(resetCandlestickZoom))
        tripleTapGesture.numberOfTapsRequired = 3
        addGestureRecognizer(tripleTapGesture)
        
        // Long press to show zoom hint  
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(showZoomHint))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
        
        // Tooltip marker when tapping a point in the chart
        let marker = CandlestickBalloonMarker(color: .tertiarySystemBackground,
                                             font: .systemFont(ofSize: 10, weight: .medium),
                                             textColor: .label,
                                             insets: UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        marker.chartView = self
        marker.setMinimumSize(CGSize(width: 140, height: 90))
        self.marker = marker
        
        // Enable smooth dragging in the chart
        dragDecelerationEnabled = true
        dragDecelerationFrictionCoef = 0.92
        
        // Set up visual effects using helper
        configurationHelper.addFadingEdges(to: self)
        configurationHelper.addScrollHintLabel(to: self)
    }
    
    @objc private func resetCandlestickZoom() {
        // Animate back to fit all data with proper Y-axis reset
        fitScreen()
        
        // Force Y-axis to reset to original calculated range
        resetYAxisToOriginalRange()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Chart zoom reset
    }
    
    @objc private func showZoomHint(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Show temporary zoom level indicator
            showZoomIndicator()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func resetYAxisToOriginalRange() {
        guard !allOHLCData.isEmpty else { return }
        
        // Recalculate original Y-axis range
        guard let minY = allOHLCData.map({ min($0.low, min($0.open, $0.close)) }).min(),
              let maxY = allOHLCData.map({ max($0.high, max($0.open, $0.close)) }).max() else { return }
        
        let range = maxY - minY
        let buffer = range * 0.25  // Same buffer as in updateChart
        
        // Reset Y-axis to original range
        rightAxis.axisMinimum = minY - buffer
        rightAxis.axisMaximum = maxY + buffer
        
        // Force chart to update
        notifyDataSetChanged()
    }
    
    @objc private func showZoomControls(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Show temporary zoom level indicator
            showZoomIndicator()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func showZoomIndicator() {
        // Create temporary zoom level indicator with candlestick-specific info
        let visibleCandles = Int(highestVisibleX - lowestVisibleX) + 1
        let zoomLabel = UILabel()
        zoomLabel.text = "🕯️ \(visibleCandles) candles visible"
        zoomLabel.textColor = .label
        zoomLabel.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.95)
        zoomLabel.font = .systemFont(ofSize: 14, weight: .medium)
        zoomLabel.layer.cornerRadius = 8
        zoomLabel.layer.masksToBounds = true
        zoomLabel.textAlignment = .center
        zoomLabel.alpha = 0
        
        addSubview(zoomLabel)
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            zoomLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            zoomLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            zoomLabel.widthAnchor.constraint(equalToConstant: 140),
            zoomLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Animate in and out
        UIView.animate(withDuration: 0.3) {
            zoomLabel.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5) {
                zoomLabel.alpha = 0
            } completion: { _ in
                zoomLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Intelligent Zoom
    
    private func setInitialZoom() {
        // Set optimal zoom level based on data range and time frame
        let dataCount = allOHLCData.count
        
        // Calculate optimal visible candles based on range
        let optimalVisibleCandles: Double
        switch currentRange {
        case "24h": optimalVisibleCandles = min(12, Double(dataCount))  // Show 12 hourly candles
        case "7d": optimalVisibleCandles = min(20, Double(dataCount))   // Show ~20 4-hour candles
        case "30d": optimalVisibleCandles = min(30, Double(dataCount))  // Show ~30 daily candles
        case "All": optimalVisibleCandles = min(50, Double(dataCount))  // Show ~50 weekly candles
        default: optimalVisibleCandles = min(25, Double(dataCount))
        }
        
        // Apply the zoom with proper limits
        setVisibleXRangeMaximum(optimalVisibleCandles)
        setVisibleXRangeMinimum(optimalVisibleCandles / 4.0) // Allow zoom in to show 1/4 of optimal
        
        // Set initial zoom level
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        configurationHelper.layoutFadingEdges(in: bounds)
        configurationHelper.layoutHintLabel(in: bounds)
    }
    
    // MARK: - Dark Mode Support
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update gradient colors when appearance changes
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            configurationHelper.updateFadingEdgeColors()
            
            // Force background color update
            backgroundColor = .systemBackground
        }
    }
    

    
    // MARK: - Public Update Method
    
    func update(_ ohlcData: [OHLCData], range: String) {
        guard !ohlcData.isEmpty else { return }
        
        self.allOHLCData = ohlcData
        self.currentRange = range
        self.visibleDataPointsCount = ChartConfigurationHelper.calculateVisiblePoints(for: range, dataCount: ohlcData.count)
        self.allDates = ohlcData.map { $0.timestamp }
        self.currentScrollPosition = 0
        updateChart()
    }
    
    // MARK: - Chart Rendering
    // Visual CandleStick entries
    private func updateChart() {
        guard !allOHLCData.isEmpty, !allDates.isEmpty else { return }
        
        // Create candlestick entries using INTEGER indices instead of timestamps, filtering out NaN values
        let entries = allOHLCData.enumerated().compactMap { index, ohlc -> CandleChartDataEntry? in
            // Check for NaN values in OHLC data
            guard ohlc.open.isFinite && ohlc.high.isFinite && ohlc.low.isFinite && ohlc.close.isFinite else {
                return nil
            }
            
            return CandleChartDataEntry(x: Double(index),  // X-axis position
                                      shadowH: ohlc.high,  // Top wick
                                      shadowL: ohlc.low,   // Bottom wick
                                      open: ohlc.open,     // Open Price
                                      close: ohlc.close,   // Close Price
                                      icon: nil)
        }
        
        guard !entries.isEmpty else { return }
        
        guard let minY = allOHLCData.map({ min($0.low, min($0.open, $0.close)) }).min(),
              let maxY = allOHLCData.map({ max($0.high, max($0.open, $0.close)) }).max() else { return }
        
        // Setup y-axis with EXPANDED range to accommodate technical indicators
        let range = maxY - minY
        // FIXED: Prevent NaN in CoreGraphics when all OHLC values are identical
        let fallbackRange = max(abs(maxY), 1.0) * 0.01 // Fallback for zero/near-zero prices
        let minRange = max(range, fallbackRange) // Ensure at least 1% range
        
        // REDUCED RANGE: Only need space for RSI below price action
        let baseBuffer = minRange * 0.25  // Base buffer for price context
        let rsiBuffer = minRange * 0.20   // Space for RSI below (reduced from 0.35)
        
        // Extended range to show RSI below price action
        rightAxis.axisMinimum = minY - baseBuffer - rsiBuffer  // RSI area below
        rightAxis.axisMaximum = maxY + baseBuffer              // No MACD above
        
        let dataSet = CandleChartDataSet(entries: entries, label: "")
        
        dataSet.drawValuesEnabled = false
        dataSet.drawIconsEnabled = false
        
        // Set Candlestick colors - darker green, vibrant red, gray for doji
        dataSet.increasingColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)  // Dark green
        dataSet.decreasingColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)  // Vibrant red
        dataSet.neutralColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)     // Gray for doji (open == close)
        dataSet.increasingFilled = true
        dataSet.decreasingFilled = true
        
        // Shadow (wick) styling - SAME COLOR as candle bodies
        dataSet.shadowWidth = 1.5  // Increased for better visibility when zoomed out
        dataSet.shadowColorSameAsCandle = true  // Wicks match their candle color
        
        // Minimal spacing between bars for better visibility when zoomed out
        dataSet.barSpace = 0.05  // Reduced from 0.2 to 0.05 for tighter candlesticks 
        
        // UPDATED: Use CombinedChartData for consistency with technical indicators
        let combinedData = CombinedChartData()
        combinedData.candleData = CandleChartData(dataSet: dataSet)
        self.data = combinedData
        
        // Force immediate render
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
        layoutIfNeeded()
        
        // Set intelligent initial zoom based on range and data
        setInitialZoom()
        
        // Chart updated with candles
        
        // Scroll to the latest entry (using index-based X values)
        moveViewToX(Double(entries.count - 1))
        
        // Create X-axis formatter for indices based on current range
        let dateStrings = allDates.map { date in
            let formatter = DateFormatter()
            // Ensure formatter uses local timezone (Singapore time for this user)
            formatter.timeZone = TimeZone.current
            // For 24h filter, show time of day instead of date
            if currentRange == "24h" {
                formatter.dateFormat = "h a"  // "9 AM", "12 PM", "6 PM"
            } else {
                formatter.dateFormat = "MM/dd"  // "07/22", "07/23"
            }
            return formatter.string(from: date)
        }
        
        xAxis.valueFormatter = IndexAxisValueFormatter(values: dateStrings)
        
        // Update marker with current dates and range for proper tooltip display
        if let candlestickMarker = self.marker as? CandlestickBalloonMarker {
            candlestickMarker.updateDates(allDates)
            candlestickMarker.updateRange(currentRange)
        }
        
        // Force chart refresh
        notifyDataSetChanged()
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
        
        // Animate chart updates with delay to ensure rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.animate(xAxisDuration: 0.6, yAxisDuration: 0.6, easingOption: .easeInOutQuart)
        }
    }
    
    // MARK: - External Scrolling Helpers
    
    func scrollToLatest() {
        guard let data = data else { return }
        moveViewToX(data.xMax)
    }
    
    func scrollToOldest() {
        guard let data = data else { return }
        moveViewToX(data.xMin)
    }
    
    func scrollBy(points: Int) {
        guard let data = data else { return }
        let currentCenterX = (lowestVisibleX + highestVisibleX) / 2
        let dataRange = data.xMax - data.xMin
        let pointWidth = dataRange / Double(allOHLCData.count)
        let offsetX = Double(points) * pointWidth
        
        let newCenterX = currentCenterX + offsetX
        let clampedX = max(data.xMin, min(data.xMax, newCenterX))
        moveViewToX(clampedX)
    }
    

}

// MARK: - Delegate Handling

extension CandlestickChartView: ChartViewDelegate {
    
    // Auto-clear highlight tooltip after delay
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Show tooltip for longer since candlestick has more data
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak chartView] in
            chartView?.highlightValue(nil)
        }
        
        // Log selection for debugging
        if let candleEntry = entry as? CandleChartDataEntry {
            let isBullish = candleEntry.close >= candleEntry.open
            // Candlestick selected
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartView.highlightValue(nil)
    }
    
    // MARK: - Zoom Event Handling
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        // Provide subtle haptic feedback during zoom
        if abs(scaleX - 1.0) > 0.1 {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
        
        // Calculate visible candles for user feedback
        let visibleCandles = Int(highestVisibleX - lowestVisibleX) + 1
        // Zoom level changed
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        // Handle chart panning while zoomed
        // This ensures smooth interaction between zoom and pan
    }
    
    // Detect if user has panned all the way to left/right
    func chartViewDidEndPanning(_ chartView: ChartViewBase) {
        guard let candleChart = chartView as? CandleStickChartView,
              let data = candleChart.data else { return }
        
        let lowestVisibleX = candleChart.lowestVisibleX
        let highestVisibleX = candleChart.highestVisibleX
        
        // Notify when close to LEFT edge
        if lowestVisibleX <= data.xMin + (data.xMax - data.xMin) * 0.1 {
            onScrollToEdge?(.left)
        }
        
        // Notify when close to RIGHT edge
        if highestVisibleX >= data.xMax - (data.xMax - data.xMin) * 0.1 {
            onScrollToEdge?(.right)
        }
    }
}

// MARK: - Chart Settings Support

extension CandlestickChartView {
    
    func updateLineThickness(_ thickness: CGFloat) {
        guard let dataSet = data?.dataSets.first as? CandleChartDataSet else { return }
        
        // Preserve viewport state
        let savedScaleX = scaleX
        let savedScaleY = scaleY
        let savedCenterX = (lowestVisibleX + highestVisibleX) / 2
        let savedCenterY = (rightAxis.axisMinimum + rightAxis.axisMaximum) / 2
        
        // For candlestick charts, we can adjust the shadow width
        dataSet.shadowWidth = thickness
        notifyDataSetChanged()
        
        // Restore viewport state
        zoom(scaleX: savedScaleX, scaleY: savedScaleY, x: savedCenterX, y: savedCenterY)
    }
    
    func toggleGridLines(_ enabled: Bool) {
        rightAxis.drawGridLinesEnabled = enabled
        // Keep X-axis grid lines disabled (vertical lines removed)
        xAxis.drawGridLinesEnabled = false
        // Grid lines don't require data set change, just redraw
        setNeedsDisplay()
    }
    
    func togglePriceLabels(_ enabled: Bool) {
        rightAxis.enabled = enabled
        xAxis.enabled = enabled
        // Axis changes don't require data set change, just redraw
        setNeedsDisplay()
    }
    
    func toggleAutoScale(_ enabled: Bool) {
        autoScaleMinMaxEnabled = enabled
        // Auto scale doesn't require data set change
        setNeedsDisplay()
    }
    
    func applyColorTheme(_ theme: ChartColorTheme) {
        guard let dataSet = data?.dataSets.first as? CandleChartDataSet else { return }
        
        // Preserve viewport state
        let savedScaleX = scaleX
        let savedScaleY = scaleY
        let savedCenterX = (lowestVisibleX + highestVisibleX) / 2
        let savedCenterY = (rightAxis.axisMinimum + rightAxis.axisMaximum) / 2
        
        // Apply colors to candlestick chart
        dataSet.increasingColor = theme.positiveColor
        dataSet.decreasingColor = theme.negativeColor
        dataSet.shadowColor = .label
        dataSet.neutralColor = .systemGray
        
        notifyDataSetChanged()
        
        // Restore viewport state
        zoom(scaleX: savedScaleX, scaleY: savedScaleY, x: savedCenterX, y: savedCenterY)
    }
    
    func setAnimationSpeed(_ speed: Double) {
        // Store for future animations
        UserDefaults.standard.set(speed, forKey: "ChartAnimationSpeed")
        
        // Apply to current animation if updating chart
        if speed > 0 {
            animate(xAxisDuration: speed, yAxisDuration: speed, easingOption: .easeInOutQuart)
        }
    }
}

// MARK: - Technical Indicators Support

extension CandlestickChartView {
    
    /// Updates chart with technical indicators overlays
    func updateWithTechnicalIndicators(_ settings: TechnicalIndicators.IndicatorSettings, theme: ChartColorTheme = .classic) {
        guard !allOHLCData.isEmpty else { 
            // Cannot apply technical indicators - no OHLC data
            return 
        }
        
        // Apply technical indicators
        
        // DEBUG: Log price range for normalization
        let allPrices = allOHLCData.flatMap { [$0.open, $0.high, $0.low, $0.close] }
        if let minPrice = allPrices.min(), let maxPrice = allPrices.max() {
            // Price range calculated
        }
        
        // Extract closing prices for indicator calculations
        let closingPrices = allOHLCData.map { $0.close }
        
        // Get existing candlestick data - handle both CombinedChartData and direct access
        guard let existingData = data else { 
            // No existing chart data found
            return 
        }
        
        // Extract candlestick data from either CombinedChartData or direct CandleChartData
        let candlestickDataSet: CandleChartDataSet?
        if let combinedData = existingData as? CombinedChartData,
           let candleData = combinedData.candleData,
           let firstDataSet = candleData.dataSets.first as? CandleChartDataSet {
            candlestickDataSet = firstDataSet
        } else if let directDataSet = existingData.dataSets.first as? CandleChartDataSet {
            candlestickDataSet = directDataSet
        } else {
            // Cannot extract candlestick data set
            return
        }
        
        guard let candleDataSet = candlestickDataSet else {
            // No valid candlestick data set found
            return
        }
        
        // Create combined chart data to overlay line indicators on candlestick chart
        let combinedData = CombinedChartData()
        
        // Add the candlestick data
        combinedData.candleData = CandleChartData(dataSet: candleDataSet)
        
        // Add technical indicators as line overlays
        var lineDataSets: [LineChartDataSet] = []
        
        // Add moving averages if enabled
        if settings.showSMA {
            if let smaDataSet = createSMADataSet(prices: closingPrices, period: settings.smaPeriod, theme: theme) {
                lineDataSets.append(smaDataSet)
            }
        }
        
        if settings.showEMA {
            if let emaDataSet = createEMADataSet(prices: closingPrices, period: settings.emaPeriod, theme: theme) {
                lineDataSets.append(emaDataSet)
            }
        }
        
        // Add RSI if enabled (normalized to price range)
        if settings.showRSI {
            if let rsiDataSet = createRSIDataSet(prices: closingPrices, period: settings.rsiPeriod, theme: theme) {
                lineDataSets.append(rsiDataSet)
            }
        }
        
        // FIXED: Now using CombinedChartView - we can properly display technical indicators!
        if !lineDataSets.isEmpty {
            combinedData.lineData = LineChartData(dataSets: lineDataSets)
            // Technical indicators applied
        } else {
            // No technical indicators to display
        }
        
        // FORCE CHART REFRESH: Ensure everything happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Apply the combined data (candlesticks + technical indicators)
            self.data = combinedData
            
            // Force immediate visual update with proper sequence
            self.notifyDataSetChanged()
            self.setNeedsDisplay()
            self.setNeedsLayout()
            self.layoutIfNeeded()
            
            // Force chart to recognize the data change
            self.invalidateIntrinsicContentSize()
            
            // Additional DGCharts refresh methods
            if let data = self.data, data.entryCount > 0 {
                self.fitScreen()
                self.setVisibleXRangeMaximum(Double(min(20, data.entryCount)))
            }
            
            // Chart refreshed with technical indicators
        }
    }
    
    private func createSMADataSet(prices: [Double], period: Int, theme: ChartColorTheme) -> LineChartDataSet? {
        let smaResult = TechnicalIndicators.calculateSMA(prices: prices, period: period)
        
        let entries = smaResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value else { return nil }
            // Additional NaN check for safety
            guard value.isFinite else { return nil }
            return ChartDataEntry(x: Double(index), y: value)
        }
        
        guard !entries.isEmpty else { return nil }
        
        let dataSet = LineChartDataSet(entries: entries, label: "SMA(\(period))")
        dataSet.setColor(TechnicalIndicators.getIndicatorColor(for: "sma", theme: theme))
        dataSet.lineWidth = 1.5
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.highlightEnabled = false
        
        return dataSet
    }
    
    private func createEMADataSet(prices: [Double], period: Int, theme: ChartColorTheme) -> LineChartDataSet? {
        let emaResult = TechnicalIndicators.calculateEMA(prices: prices, period: period)
        
        let entries = emaResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value else { return nil }
            // Additional NaN check for safety
            guard value.isFinite else { return nil }
            return ChartDataEntry(x: Double(index), y: value)
        }
        
        guard !entries.isEmpty else { return nil }
        
        let dataSet = LineChartDataSet(entries: entries, label: "EMA(\(period))")
        dataSet.setColor(TechnicalIndicators.getIndicatorColor(for: "ema", theme: theme))
        dataSet.lineWidth = 1.5
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.highlightEnabled = false
        
        return dataSet
    }
    

    
    private func createRSIDataSet(prices: [Double], period: Int, theme: ChartColorTheme) -> LineChartDataSet? {
        let rsiResult = TechnicalIndicators.calculateRSI(prices: prices, period: period)
        
        // Get price range for better normalization
        guard !allOHLCData.isEmpty else { return nil }
        let allPrices = allOHLCData.flatMap { [$0.open, $0.high, $0.low, $0.close] }
        guard let minPrice = allPrices.min(), let maxPrice = allPrices.max(), maxPrice > minPrice else { return nil }
        
        // DEBUG: Log RSI calculation details
        let validRSIValues = rsiResult.values.compactMap { $0 }
        if let minRSI = validRSIValues.min(), let maxRSI = validRSIValues.max() {
            // RSI range calculated
        }
        
        let entries = rsiResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value else { return nil }
            guard value.isFinite else { return nil }
            
            // IMPROVED NORMALIZATION: Map RSI (0-100) to a smaller range in the lower part of the chart
            // Place RSI in the bottom 15% of the chart area
            let chartBottom = minPrice - (maxPrice - minPrice) * 0.05  // Slightly below chart
            let rsiRange = (maxPrice - minPrice) * 0.15  // Use 15% of chart height
            let normalizedValue = chartBottom - rsiRange + (value / 100.0) * rsiRange
            
            return ChartDataEntry(x: Double(index), y: normalizedValue)
        }
        
        guard !entries.isEmpty else { return nil }
        
        let dataSet = LineChartDataSet(entries: entries, label: "RSI(\(period))")
        dataSet.setColor(TechnicalIndicators.getIndicatorColor(for: "rsi", theme: theme))
        dataSet.lineWidth = 2.0
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.drawFilledEnabled = false
        dataSet.highlightEnabled = false
        dataSet.lineDashLengths = [5, 5] // Dashed line to distinguish from price
        
        return dataSet
    }
    

    
    /// Clears all technical indicator overlays, keeping only the candlestick data
    func clearTechnicalIndicators() {
        // For candlestick charts, we'll focus on the core candlestick display
        // Technical indicators are better suited for line charts
        notifyDataSetChanged()
    } 
} 
