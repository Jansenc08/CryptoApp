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
    
    // MARK: - Label Management
    private var labelManager: ChartLabelManager?
    
    /// Public access to label manager for external coordination
    var chartLabelManager: ChartLabelManager? {
        return labelManager
    }
    
    // MARK: - Dynamic Value Tracking (CoinMarketCap Style)
    private var currentSMADataSet: LineChartDataSet?
    private var currentEMADataSet: LineChartDataSet?
    private var currentRSIResult: TechnicalIndicators.RSIResult?
    private var currentTechnicalSettings: TechnicalIndicators.IndicatorSettings?
    private var currentTheme: ChartColorTheme?
    
    // Throttling for smooth scrolling
    private var updateTimer: Timer?
    
    // Viewport monitoring for scroll-based updates
    private var lastVisibleX: Double = 0
    private var viewportMonitorTimer: Timer?
    
    // Visual indicator for monitored candlestick
    private var monitoringIndicatorView: UIView?
    
    // Current price indicator (TradingView style)
    private var currentPriceLineView: UIView?
    private var currentPriceLabelView: UIView?
    private var currentPriceLabel: UILabel?
    
    // Callback to notify when user scrolls to chart edge
    var onScrollToEdge: ((ScrollDirection) -> Void)?
    
    // Scroll direction used for edge detection
    enum ScrollDirection {
        case left, right
    }
    
    // Public method to dismiss tooltip - called from parent view
    func dismissTooltip() {
        print("🕯️💥 CandlestickChartView: dismissTooltip() called")
        print("🕯️💥 Highlighted count before dismiss: \(highlighted.count)")
        highlightValue(nil)
        resetToLatestValues()
        print("🕯️💥 Highlighted count after dismiss: \(highlighted.count)")
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
        configure()
        setupLabelManager()
        setupCurrentPriceIndicator()
        setupTraitObservation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
        configure()
        setupLabelManager()
        setupCurrentPriceIndicator()
        setupTraitObservation()
    }
    
    private func setupLabelManager() {
        labelManager = ChartLabelManager(parentChart: self)
    }
    
    // MARK: - Current Price Indicator Setup
    
    private func setupCurrentPriceIndicator() {
        // NOTE: Current price text is displayed in the top label container alongside SMA/EMA
        // But we still show a subtle dotted horizontal line for visual price level reference
        
        // Create horizontal dotted line for current price level
        currentPriceLineView = UIView()
        currentPriceLineView?.backgroundColor = UIColor.clear // We'll use a CAShapeLayer instead
        currentPriceLineView?.translatesAutoresizingMaskIntoConstraints = false
        currentPriceLineView?.isHidden = true
        currentPriceLineView?.alpha = 0.6 // Reduced opacity for subtlety
        
        // Add to chart
        if let lineView = currentPriceLineView {
            addSubview(lineView)
        }
    }
    
    // MARK: - Current Price Indicator Updates
    
    private func updateCurrentPriceIndicator(for candlestick: OHLCData) {
        guard let lineView = currentPriceLineView else { 
            return 
        }
        
        // Use closing price as the current price
        let currentPrice = candlestick.close
        
        // Determine color based on price movement (bullish/bearish)
        let indicatorColor = candlestick.isBullish ? UIColor.systemGreen : UIColor.systemRed
        
        // Convert price to Y position on chart
        let yPosition = getYPositionForPrice(currentPrice)
        
        // CRITICAL: Validate Y position to prevent NaN errors
        guard yPosition.isFinite else {
            print("⚠️ Invalid yPosition in price indicator: \(yPosition) for price: \(currentPrice)")
            return
        }
        
        // Get the actual chart content area for accurate line positioning
        let chartContentRect = contentRect
        let lineStartX = max(0, chartContentRect.minX)
        let lineEndX = min(bounds.width, chartContentRect.maxX)
        let lineWidth = lineEndX - lineStartX
        
        // CRITICAL: Validate all frame values to prevent CoreGraphics errors
        guard lineStartX.isFinite && lineWidth.isFinite && lineWidth > 0 && 
              (yPosition - 0.5).isFinite else {
            print("⚠️ Invalid frame values in price indicator")
            print("lineStartX: \(lineStartX), lineWidth: \(lineWidth), yPosition: \(yPosition)")
            return
        }
        
        // Position the horizontal line across the chart content area
        // Make sure the Y position is relative to the chart view bounds
        lineView.frame = CGRect(
            x: lineStartX,
            y: yPosition - 0.5, // Half line height for centering
            width: lineWidth,
            height: 1
        )
        
        // Remove any existing shape layers
        lineView.layer.sublayers?.removeAll()
        
        // Create dotted line pattern using CAShapeLayer
        let dottedLine = CAShapeLayer()
        dottedLine.strokeColor = indicatorColor.cgColor
        dottedLine.lineWidth = 1.0
        dottedLine.lineDashPattern = [4, 4] // 4 points dash, 4 points gap
        
        // Create the path for the line using the actual line width
        // CRITICAL: Validate lineWidth to prevent CGPath errors
        guard lineWidth.isFinite && lineWidth > 0 else {
            print("⚠️ Invalid lineWidth in dotted line: \(lineWidth)")
            return
        }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0.5))
        path.addLine(to: CGPoint(x: lineWidth, y: 0.5))
        
        dottedLine.path = path.cgPath
        lineView.layer.addSublayer(dottedLine)
        
        // Show the line
        lineView.isHidden = false
        
        // Bring to front to ensure visibility over candlesticks
        bringSubviewToFront(lineView)
    }
    
    /// Cached transformer for performance (Swift best practice)
    private var cachedRightAxisTransformer: Transformer?
    
    private func getYPositionForPrice(_ price: Double) -> CGFloat {
        // CRITICAL: Validate input price to prevent NaN propagation
        guard price.isFinite else {
            print("⚠️ Invalid price in getYPositionForPrice: \(price)")
            return contentRect.midY
        }
        
        // SWIFT BEST PRACTICE: Cache expensive transformer calls
        if cachedRightAxisTransformer == nil {
            cachedRightAxisTransformer = getTransformer(forAxis: .right)
        }
        
        guard let transformer = cachedRightAxisTransformer else {
            return contentRect.midY // Fallback
        }
        
        let pixelY = transformer.pixelForValues(x: 0, y: price)
        
        // CRITICAL: Validate pixelY before using it
        guard pixelY.y.isFinite else {
            print("⚠️ Invalid pixelY from transformer: \(pixelY) for price: \(price)")
            return contentRect.midY
        }
        
        // Swift best practice: Safe bounds checking
        let result = max(contentRect.minY, min(contentRect.maxY, pixelY.y))
        
        // Final validation of result
        return result.isFinite ? result : contentRect.midY
    }
    
    private func hideCurrentPriceIndicator() {
        currentPriceLineView?.isHidden = true
        // Note: currentPriceLabelView is no longer used - price text is in top container
    }
    
    // MARK: - Public Price Indicator Controls
    
    /// Toggles the current price indicator visibility
    func setCurrentPriceIndicatorVisible(_ visible: Bool) {
        if visible && !allOHLCData.isEmpty {
            // Trigger a visible range update which will update the price indicator
            updateValuesForVisibleRange()
        } else {
            hideCurrentPriceIndicator()
        }
    }
    
    // MARK: - Precise Index Calculation for Zoom Levels
    
    /// Calculates the rightmost visible candlestick index using DGCharts built-in properties (optimized)
    private func calculateRightmostVisibleIndex() -> Int {
        guard !allOHLCData.isEmpty else { return 0 }
        
        // SWIFT BEST PRACTICE: Use DGCharts built-in highestVisibleX (O(1) complexity)
        // This is the most efficient and accurate method
        
        let rightmostDataX = highestVisibleX
        let candidateIndex = Int(rightmostDataX.rounded())
        
        // ENHANCEMENT: When scrolling in the extended padding area (before/after actual data),
        // clamp to show the first or last candlestick's data for price detection
        let finalIndex = max(0, min(candidateIndex, allOHLCData.count - 1))
        
        return finalIndex
    }
    
    // Note: Price indicator updates are now integrated directly into performVisibleRangeUpdate()
    // This ensures the price indicator uses precise index calculation for all zoom levels
    

    
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
        highlightPerDragEnabled = true  // Enable drag highlighting for dynamic value updates
        // Enable dynamic Y-axis autoscaling so axis adapts when zooming/panning
        autoScaleMinMaxEnabled = true
        
        // Configure axes for combined chart
        leftAxis.enabled = false
        rightAxis.enabled = true
        rightAxis.labelFont = .systemFont(ofSize: 10) // Slightly larger for better readability
        rightAxis.labelTextColor = .label // Use primary label color for better visibility
        rightAxis.drawGridLinesEnabled = true
        rightAxis.gridColor = .systemGray5
        rightAxis.gridLineWidth = 0.5
        rightAxis.drawAxisLineEnabled = false // Remove axis line for seamless look
        
        xAxis.enabled = true
        xAxis.labelPosition = .bottom
        xAxis.labelFont = .systemFont(ofSize: 10) // Slightly larger for better readability
        xAxis.labelTextColor = .label // Use primary label color for better visibility
        xAxis.drawGridLinesEnabled = false  // Remove vertical grid lines
        xAxis.gridColor = .systemGray5
        xAxis.gridLineWidth = 0.5
        xAxis.drawAxisLineEnabled = false // Remove axis line for seamless look
        
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
        
        // OKX-style tooltip marker - adapts to light/dark mode
        let adaptiveBackgroundColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 0.95) // Dark gray for dark mode
            default:
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)   // White for light mode
            }
        }
        let adaptiveTextColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.white    // White text for dark mode
            default:
                return UIColor.black    // Black text for light mode
            }
        }
        let marker = CandlestickBalloonMarker(color: adaptiveBackgroundColor,
                                             font: .monospacedSystemFont(ofSize: 10, weight: .medium),
                                             textColor: adaptiveTextColor,
                                             insets: UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10))
        marker.chartView = self
        marker.setMinimumSize(CGSize(width: 130, height: 90))  // Slightly wider for better spacing
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
        
        // Update price indicator position when layout changes (orientation, zoom, etc.)
        // Use a delayed update to ensure chart layout is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let self = self, !self.allOHLCData.isEmpty {
                self.updateValuesForVisibleRange()
            }
        }
    }
    
    // MARK: - Dark Mode Support
    
    private func setupTraitObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
                // Update gradient colors when appearance changes
                self.configurationHelper.updateFadingEdgeColors()
                
                // Force background color update
                self.backgroundColor = .systemBackground
            }
        }
    }
    
    @available(iOS, deprecated: 17.0, message: "Use registerForTraitChanges instead")
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 17.0, *) {
            // Handled by registerForTraitChanges
        } else {
            // Fallback for iOS < 17.0
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                configurationHelper.updateFadingEdgeColors()
                backgroundColor = .systemBackground
            }
        }
    }
    

    
    // MARK: - Public Update Method
    
    func update(_ ohlcData: [OHLCData], range: String) {
        guard !ohlcData.isEmpty else { 
            hideCurrentPriceIndicator()
            return 
        }
        
        self.allOHLCData = ohlcData
        self.currentRange = range
        self.visibleDataPointsCount = ChartConfigurationHelper.calculateVisiblePoints(for: range, dataCount: ohlcData.count)
        self.allDates = ohlcData.map { $0.timestamp }
        self.currentScrollPosition = 0
        
        // SWIFT BEST PRACTICE: Invalidate cache when data changes to prevent stale transformer references
        cachedRightAxisTransformer = nil
        
        updateChart()
        
        // ENHANCEMENT: Position chart to show latest data with room to scroll past the last candlestick
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.positionChartForOptimalScrolling()
        }
        
        // Start viewport monitoring for scroll-based updates
        startViewportMonitoring()
        
        // Show price indicator for the rightmost visible candlestick
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateValuesForVisibleRange()
        }
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
        
        // Setup Y-axis handling: autoscale when enabled, otherwise fixed bounds
        if autoScaleMinMaxEnabled {
            rightAxis.resetCustomAxisMin()
            rightAxis.resetCustomAxisMax()
            
            // IMPORTANT: Set label properties for autoscale mode
            rightAxis.labelCount = 6
            rightAxis.forceLabelsEnabled = false
            rightAxis.granularityEnabled = false
            rightAxis.valueFormatter = PriceFormatter()
            rightAxis.minWidth = 60
        } else {
            // Setup y-axis - main price chart only (RSI will have separate scaling)
            let range = maxY - minY
            // FIXED: Prevent NaN in CoreGraphics when all OHLC values are identical
            let fallbackRange = max(abs(maxY), 1.0) * 0.01 // Fallback for zero/near-zero prices
            let minRange = max(range, fallbackRange) // Ensure at least 1% range
            
            // Main chart area - price data only
            let baseBuffer = minRange * 0.15  // Standard buffer for price context
            
            // Calculate axis bounds
            var axisMin = minY - baseBuffer
            var axisMax = maxY + baseBuffer
            // Never show negative price on Y-axis for price section
            if axisMin < 0 {
                axisMin = 0
                if axisMax <= axisMin {
                    axisMax = axisMin + max(minRange, 1e-12)
                }
            }
            
            // CRITICAL: Validate axis values before setting to prevent NaN errors
            guard axisMin.isFinite && axisMax.isFinite && axisMax > axisMin else {
                print("⚠️ Invalid axis values in CandlestickChartView - skipping axis configuration")
                print("axisMin: \(axisMin), axisMax: \(axisMax), minY: \(minY), maxY: \(maxY)")
                return
            }
            
            // Price chart axis (RSI will use separate coordinate space)
            rightAxis.axisMinimum = axisMin
            rightAxis.axisMaximum = axisMax
        }
        
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
        let savedThickness = UserDefaults.standard.double(forKey: "ChartLineThickness")
        dataSet.shadowWidth = CGFloat(savedThickness > 0 ? savedThickness : 1.5)  // Respect saved thickness
        dataSet.shadowColorSameAsCandle = true  // Wicks match their candle color
        
        // Minimal spacing between bars for better visibility when zoomed out
        dataSet.barSpace = 0.05  // Reduced from 0.2 to 0.05 for tighter candlesticks 
        
        // UPDATED: Use CombinedChartData for consistency with technical indicators
        let combinedData = CombinedChartData()
        combinedData.candleData = CandleChartData(dataSet: dataSet)

        self.data = combinedData
        
        // ENHANCEMENT: Allow scrolling past the first candlestick by extending the X-axis range
        // Add significant padding to allow scrolling well before the first candlestick (historical data side)
        // Special handling for 24h timeframe which needs more padding
        let paddingMultiplier = currentRange == "24h" ? 1.0 : 0.5 // 100% for 24h, 50% for others
        let paddingPoints = max(Double(visibleDataPointsCount) * paddingMultiplier, 15.0) // Reduced minimum
        let lastDataIndex = Double(entries.count - 1)
        
        // Set X-axis range to include the padding - only at the beginning (left side - historical data)
        xAxis.axisMinimum = -paddingPoints // Allow scrolling before the first candlestick
        xAxis.axisMaximum = lastDataIndex // Keep the end at the last candlestick
        
        // Force immediate render
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
        layoutIfNeeded()
        
        // Set intelligent initial zoom based on range and data
        setInitialZoom()
        
        // Chart updated with candles
        
        // Position chart to show latest candlesticks with some scroll space
        let lastIndex = Double(entries.count - 1)
        
        // For small datasets, show all data centered
        if entries.count <= 20 {
            fitScreen()
        } else {
            // For larger datasets, position to show latest with 10% buffer for scrolling
            let bufferCandles = max(3.0, Double(entries.count) * 0.1)
            moveViewToX(lastIndex - bufferCandles)
        }
        
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
    
    // MARK: - Dynamic Value Updates (CoinMarketCap Style)
    
    /// Updates indicator labels with values at the specified chart position
    private func updateDynamicValues(at xIndex: Int) {
        guard let labelManager = labelManager,
              let settings = currentTechnicalSettings,
              let theme = currentTheme else { return }
        
        labelManager.updateLabelsAtPosition(
            xIndex: xIndex,
            smaDataSet: currentSMADataSet,
            emaDataSet: currentEMADataSet,
            rsiResult: currentRSIResult,
            settings: settings,
            theme: theme
        )
    }
    
    /// Resets labels to show the latest (most recent) values
    private func resetToLatestValues() {
        guard let labelManager = labelManager,
              let settings = currentTechnicalSettings,
              let theme = currentTheme else { return }
        
        // Get the last index (most recent data)
        let lastIndex = max(0, allOHLCData.count - 1)
        
        labelManager.updateLabelsAtPosition(
            xIndex: lastIndex,
            smaDataSet: currentSMADataSet,
            emaDataSet: currentEMADataSet,
            rsiResult: currentRSIResult,
            settings: settings,
            theme: theme
        )
    }
    
    /// Updates indicator values based on the current visible range (optimized)
    private func updateValuesForVisibleRange() {
        // SWIFT BEST PRACTICE: Use DispatchQueue for better performance than Timer
        // Debounce rapid calls using work items
        updateTimer?.invalidate()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.performVisibleRangeUpdate()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
    
    private func performVisibleRangeUpdate() {
        guard !allOHLCData.isEmpty else { return }
        
        // Get a reliable rightmost visible candlestick index using screen coordinates
        let targetIndex = calculateRightmostVisibleIndex()
        
        // 🎯 UPDATE PRICE LABEL: Use precise index calculation
        let candlestick = allOHLCData[targetIndex]
        
        // Update the price label in the top container alongside SMA/EMA
        labelManager?.updateCurrentPrice(price: candlestick.close, isBullish: candlestick.isBullish)
        
        // Update the dotted price line indicator
        updateCurrentPriceIndicator(for: candlestick)
        
        // Only update technical indicators if settings are available
        guard let labelManager = labelManager,
              let settings = currentTechnicalSettings,
              let theme = currentTheme else { return }
        
        // Extract closing prices for data count check
        let closingPrices = allOHLCData.map { $0.close }
        
        // Check if we have enough data for any enabled indicators
        let hasEnoughDataForSMA = settings.showSMA && closingPrices.count >= settings.smaPeriod
        let hasEnoughDataForEMA = settings.showEMA && closingPrices.count >= settings.emaPeriod
        let hasEnoughDataForRSI = settings.showRSI && closingPrices.count >= (settings.rsiPeriod + 1)
        
        // If no indicators have enough data, skip position updates to preserve the "Need more data" messages
        guard hasEnoughDataForSMA || hasEnoughDataForEMA || hasEnoughDataForRSI else { return }
        
        // Update labels with values at this position
        labelManager.updateLabelsAtPosition(
            xIndex: targetIndex,
            smaDataSet: currentSMADataSet,
            emaDataSet: currentEMADataSet,
            rsiResult: currentRSIResult,
            settings: settings,
            theme: theme,
            dataPointCount: allOHLCData.count
        )
    }
    
    // MARK: - Chart Navigation
    
    /// Scrolls the chart to show the latest (most recent) data
    private func scrollToLatestData() {
        guard let data = data else { return }
        
        // Move to the rightmost position (latest data) like ChartView does
        moveViewToX(data.xMax)
        
        print("📍 Auto-scrolled to latest data at position \(data.xMax)")
    }
    
    /// Positions the chart optimally to show the latest data while allowing scrolling past the last candlestick
    private func positionChartForOptimalScrolling() {
        guard !allOHLCData.isEmpty else { return }
        
        // Position the chart so the last candlestick is visible but not at the very edge
        // This allows users to immediately scroll right to see beyond the last candlestick
        let lastCandlestickIndex = Double(allOHLCData.count - 1)
        let visibleRange = Double(visibleDataPointsCount)
        
        // Position so the last candlestick is about 70% across the visible range
        // This gives more room to scroll right and see the price detection for the last candlesticks
        let targetPosition = lastCandlestickIndex - (visibleRange * 0.3)
        
        moveViewToX(max(0, targetPosition))
        
        print("📍 Positioned chart at \(targetPosition) to show last candlestick with significant scroll room")
    }
    
    // MARK: - View Lifecycle
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            // View is being removed from window, stop monitoring
            stopViewportMonitoring()
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            // Ensure cleanup when view is removed from window
            stopViewportMonitoring()
            updateTimer?.invalidate()
            updateTimer = nil
        }
    }
    
    // MARK: - Viewport Monitoring for Scroll-Based Updates
    
    /// Starts monitoring viewport changes for automatic value updates
    private func startViewportMonitoring() {
        stopViewportMonitoring()
        lastVisibleX = highestVisibleX
        
        // Only start monitoring if view is in window hierarchy
        guard window != nil else { return }
        
        // print("🚀 CandlestickChart: Starting viewport monitoring from position \(lastVisibleX)")
        
        viewportMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, self.window != nil else {
                timer.invalidate()
                return
            }
            self.checkViewportChanges()
        }
    }
    
    /// Stops viewport monitoring
    private func stopViewportMonitoring() {
        viewportMonitorTimer?.invalidate()
        viewportMonitorTimer = nil
    }
    
    /// Checks if viewport has changed and updates values accordingly
    private func checkViewportChanges() {
        let currentVisibleX = highestVisibleX
        
        // Check if viewport has changed significantly (more than 0.1 data points for more responsive updates)
        if abs(currentVisibleX - lastVisibleX) > 0.1 {
            lastVisibleX = currentVisibleX
            
            // Update all indicators (including price indicator) together
            updateValuesForVisibleRange()
        }
    }
    
    // MARK: - Visual Monitoring Indicator
    
    /// Shows a visual indicator on the candlestick being monitored
    private func showMonitoringIndicator(at index: Int) {
        guard index < allOHLCData.count else { return }
        
        // Remove existing indicator
        monitoringIndicatorView?.removeFromSuperview()
        
        // Create new indicator
        let indicator = UIView()
        indicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        indicator.layer.borderColor = UIColor.systemBlue.cgColor
        indicator.layer.borderWidth = 2.0
        indicator.layer.cornerRadius = 4.0
        indicator.isUserInteractionEnabled = false
        
        // Add to chart
        addSubview(indicator)
        monitoringIndicatorView = indicator
        
        // Position indicator at the target candlestick
        positionMonitoringIndicator(at: index)
    }
    
    /// Positions the monitoring indicator at the specified candlestick index
    private func positionMonitoringIndicator(at index: Int) {
        guard let indicator = monitoringIndicatorView,
              index < allOHLCData.count else { return }
        
        // Get chart dimensions
        let _ = bounds  // chartBounds unused
        let contentRect = contentRect
        
        // Calculate position
        let totalDataPoints = Double(allOHLCData.count)
        let xPosition = contentRect.minX + (Double(index) / totalDataPoints) * contentRect.width
        
        // Set indicator frame (vertical line spanning the chart height)
        let indicatorWidth: CGFloat = 3.0
        indicator.frame = CGRect(
            x: xPosition - indicatorWidth/2,
            y: contentRect.minY,
            width: indicatorWidth,
            height: contentRect.height
        )
    }
    
    deinit {
        // Clean up all timers and resources
        stopViewportMonitoring()
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Clean up visual indicator
        monitoringIndicatorView?.removeFromSuperview()
        monitoringIndicatorView = nil
        
        // Clear stored references
        currentSMADataSet = nil
        currentEMADataSet = nil
        currentRSIResult = nil
        currentTechnicalSettings = nil
        currentTheme = nil
        labelManager = nil
    }

}

// MARK: - Delegate Handling

extension CandlestickChartView: ChartViewDelegate {
    
    // Handle crosshair interaction for dynamic value updates
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {

        
        // Update indicator labels dynamically based on crosshair position
        updateDynamicValues(at: Int(entry.x))
        
        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.highlightValue(nil)
            self?.resetToLatestValues()
        }
        

    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartView.highlightValue(nil)
        // Reset to latest values when nothing is selected
        resetToLatestValues()

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
        print("🔍 Zoom detected - ScaleX: \(scaleX), ScaleY: \(scaleY), Visible candles: \(visibleCandles)")
        
        // Update price indicator and labels immediately when zoom level changes
        // The new screen-based calculation is zoom-independent and doesn't need delays
        updateValuesForVisibleRange()
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        // Handle chart panning while zoomed
        // This ensures smooth interaction between zoom and pan
        
        // Price indicator updates are now integrated into updateValuesForVisibleRange()
        
        // Update indicator values based on current visible range
        updateValuesForVisibleRange()
    }
    
    func chartViewDidEndPanning(_ chartView: ChartViewBase) {
        // Update values when panning ends
        updateValuesForVisibleRange()
        
        // Price indicator updates are now integrated into updateValuesForVisibleRange()
        
        // Updated edge detection logic to account for extended X-axis range
        guard let candleChart = chartView as? CandleStickChartView else { return }
        
        let lowestVisibleX = candleChart.lowestVisibleX
        let highestVisibleX = candleChart.highestVisibleX
        
        // Use the actual data bounds (not the extended axis range) for edge detection
        let actualDataMin = 0.0 // First candlestick index
        let actualDataMax = Double(allOHLCData.count - 1) // Last candlestick index
        let dataRange = actualDataMax - actualDataMin
        
        // Notify when close to LEFT edge (based on actual data, not extended range)
        // Only trigger when we're near the actual first candlestick, not the extended padding
        if lowestVisibleX >= actualDataMin - dataRange * 0.1 && lowestVisibleX <= actualDataMin + dataRange * 0.1 {
            onScrollToEdge?(.left)
        }
        
        // Notify when close to RIGHT edge (based on actual data)
        if highestVisibleX >= actualDataMax - dataRange * 0.1 {
            onScrollToEdge?(.right)
        }
    }
}

// MARK: - Chart Settings Support

extension CandlestickChartView {
    
    func updateLineThickness(_ thickness: CGFloat) {
        // Combined charts can wrap candle data inside CombinedChartData
        var candleDataSet: CandleChartDataSet?
        if let combined = data as? CombinedChartData {
            candleDataSet = combined.candleData?.dataSets.first as? CandleChartDataSet
        } else {
            candleDataSet = data?.dataSets.first as? CandleChartDataSet
        }
        guard let dataSet = candleDataSet else { return }
        
        // Preserve full viewport matrix to avoid compounding zoom
        let savedMatrix = viewPortHandler.touchMatrix
        
        // For candlestick charts, we can adjust the shadow width
        dataSet.shadowWidth = thickness
        // Ensure data object and chart refresh
        if let combined = data as? CombinedChartData {
            combined.notifyDataChanged()
        } else {
            data?.notifyDataChanged()
        }
        notifyDataSetChanged()
        // Restore previous matrix precisely (no extra zoom)
        _ = viewPortHandler.refresh(newMatrix: savedMatrix, chart: self, invalidate: true)
        // Clamp viewport if restored window is invalid
        if let d = data {
            let minX = d.xMin
            let maxX = d.xMax
            let low = lowestVisibleX
            let high = highestVisibleX
            if !low.isFinite || !high.isFinite || high <= minX || low >= maxX {
                let center = (minX + maxX) / 2
                moveViewToX(center)
            }
        }
        setNeedsDisplay()
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
        // Support both CombinedChartData and direct CandleChartData
        var candleDataSet: CandleChartDataSet?
        if let combined = data as? CombinedChartData {
            candleDataSet = combined.candleData?.dataSets.first as? CandleChartDataSet
        } else {
            candleDataSet = data?.dataSets.first as? CandleChartDataSet
        }
        guard let dataSet = candleDataSet else { return }
        
        // Preserve full viewport matrix
        let savedMatrix = viewPortHandler.touchMatrix
        
        // Apply colors to candlestick chart
        dataSet.increasingColor = theme.positiveColor
        dataSet.decreasingColor = theme.negativeColor
        dataSet.shadowColor = .label
        dataSet.neutralColor = .systemGray
        
        if let combined = data as? CombinedChartData {
            combined.notifyDataChanged()
        } else {
            data?.notifyDataChanged()
        }
        notifyDataSetChanged()
        // Restore previous matrix precisely (no extra zoom) and clamp if needed
        _ = viewPortHandler.refresh(newMatrix: savedMatrix, chart: self, invalidate: true)
        if let d = data {
            let minX = d.xMin
            let maxX = d.xMax
            let low = lowestVisibleX
            let high = highestVisibleX
            if !low.isFinite || !high.isFinite || high <= minX || low >= maxX {
                let center = (minX + maxX) / 2
                moveViewToX(center)
            }
        }
        setNeedsDisplay()
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
        if let _ = allPrices.min(), let _ = allPrices.max() {
            // Price range calculated but unused
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
        
        // Store data sets for label updates
        var smaDataSet: LineChartDataSet?
        var emaDataSet: LineChartDataSet?
        var rsiResult: TechnicalIndicators.RSIResult?
        
        // Add moving averages if enabled
        if settings.showSMA {
            smaDataSet = createSMADataSet(prices: closingPrices, period: settings.smaPeriod, theme: theme)
            if let sma = smaDataSet {
                lineDataSets.append(sma)
            }
        }
        
        if settings.showEMA {
            emaDataSet = createEMADataSet(prices: closingPrices, period: settings.emaPeriod, theme: theme)
            if let ema = emaDataSet {
                lineDataSets.append(ema)
            }
        }
        
        // Add RSI if enabled (with reference lines)
        if settings.showRSI {
            rsiResult = TechnicalIndicators.calculateRSI(prices: closingPrices, period: settings.rsiPeriod)
            let rsiDataSets = createRSIDataSets(prices: closingPrices, settings: settings, theme: theme)
            // SAFETY: Only append if we have valid data sets
            if !rsiDataSets.isEmpty {
                lineDataSets.append(contentsOf: rsiDataSets)
            }
        }
        
        // Store current data for dynamic updates
        currentSMADataSet = smaDataSet
        currentEMADataSet = emaDataSet
        currentRSIResult = rsiResult
        currentTechnicalSettings = settings
        currentTheme = theme
        
        // FIXED: Now using CombinedChartView - we can properly display technical indicators!
        if !lineDataSets.isEmpty {
            // SAFETY: Validate all data sets have entries before creating LineChartData
            let validDataSets = lineDataSets.filter { !$0.entries.isEmpty }
            if !validDataSets.isEmpty {
                combinedData.lineData = LineChartData(dataSets: validDataSets)
                // Technical indicators applied
            }
        } else {
            // No technical indicators to display
        }
        
        // Preserve current viewport state to avoid breaking zoom/scroll when applying settings
        let savedScaleX = scaleX
        let savedScaleY = scaleY
        let savedCenterX = (lowestVisibleX + highestVisibleX) / 2
        let savedCenterY = (rightAxis.axisMinimum + rightAxis.axisMaximum) / 2
        let wasZoomed = abs(savedScaleX - 1.0) > 0.01 || abs(savedScaleY - 1.0) > 0.01

        // FORCE CHART REFRESH: Ensure everything happens on main thread
        DispatchQueue.main.async { [weak self, smaDataSet, emaDataSet, rsiResult, settings, theme, savedScaleX, savedScaleY, savedCenterX, savedCenterY, wasZoomed] in
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
            
            // IMPORTANT: Do not force fit/visible range here; preserve user's current viewport
            // Restore viewport state captured before data change
            self.zoom(scaleX: savedScaleX, scaleY: savedScaleY, x: savedCenterX, y: savedCenterY)
            
            // Calculate RSI area coordinates for label positioning
            let chartHeight = self.bounds.height
            let rsiAreaTop = chartHeight * 0.75  // RSI section starts at 75% down
            let rsiAreaHeight = chartHeight * 0.25  // RSI section is 25% of chart height
            
            // Update labels with current values
            self.labelManager?.updateAllLabels(
                smaDataSet: smaDataSet,
                emaDataSet: emaDataSet,
                rsiResult: rsiResult,
                settings: settings,
                theme: theme,
                rsiAreaTop: rsiAreaTop,
                rsiAreaHeight: rsiAreaHeight,
                dataPointCount: closingPrices.count
            )
            
            // Maintain current viewport if the user was zoomed; otherwise keep existing UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if wasZoomed {
                    // When zoomed, do not auto-scroll; just update labels for current view
                    self.updateValuesForVisibleRange()
                } else {
                    // Not zoomed: keep previous behavior of showing latest and monitoring
                    self.scrollToLatestData()
                    self.updateValuesForVisibleRange()
                    self.startViewportMonitoring()
                }
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
    

    
    private func createRSIDataSets(prices: [Double], settings: TechnicalIndicators.IndicatorSettings, theme: ChartColorTheme) -> [LineChartDataSet] {
        // SAFETY: Early validation to prevent crashes
        guard !prices.isEmpty, prices.count > settings.rsiPeriod else { return [] }
        guard !allOHLCData.isEmpty else { return [] }
        
        let rsiResult = TechnicalIndicators.calculateRSI(prices: prices, period: settings.rsiPeriod, overbought: settings.rsiOverbought, oversold: settings.rsiOversold)
        
        // Get price range to position RSI below main chart
        let allPrices = allOHLCData.flatMap { [$0.open, $0.high, $0.low, $0.close] }
        guard let minPrice = allPrices.min(), let maxPrice = allPrices.max(), maxPrice > minPrice else { return [] }
        
        // Create RSI section with robust validation to prevent NaN errors
        let priceRange = maxPrice - minPrice
        
        // Validate price range is finite and reasonable
        guard priceRange.isFinite && priceRange >= 0 else {
            print("⚠️ Invalid price range: \(priceRange), minPrice: \(minPrice), maxPrice: \(maxPrice)")
            return []
        }
        
        let separationMultiplier = max(2.0, priceRange * 0.0001) // Dynamic but reasonable separation
        let rsiSectionHeight = priceRange * 0.25  // 25% of price range for RSI section
        let rsiBottom = minPrice - (priceRange * 0.1) - rsiSectionHeight
        
        // Final validation of all computed values
        guard separationMultiplier.isFinite && rsiSectionHeight.isFinite && rsiBottom.isFinite else {
            print("⚠️ Invalid RSI positioning values:")
            print("separationMultiplier: \(separationMultiplier), rsiSectionHeight: \(rsiSectionHeight), rsiBottom: \(rsiBottom)")
            return []
        }
        
        // Map RSI values (0-100) to RSI section coordinates
        let rsiEntries = rsiResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value else { return nil }
            guard value.isFinite && value >= 0 && value <= 100 else { return nil }
            guard index < allOHLCData.count else { return nil }
            
            // Map RSI (0-100) to the RSI section height
            let rsiPosition = rsiBottom + (value / 100.0) * rsiSectionHeight
            
            // Validate final position is finite before creating entry
            guard rsiPosition.isFinite else {
                print("⚠️ Invalid RSI position: \(rsiPosition) for value: \(value)")
                return nil
            }
            
            return ChartDataEntry(x: Double(index), y: rsiPosition)
        }
        
        guard !rsiEntries.isEmpty, rsiEntries.count >= 2 else { return [] }
        
        var dataSets: [LineChartDataSet] = []
        
        // Main RSI line - Professional styling
        let rsiDataSet = LineChartDataSet(entries: rsiEntries, label: "RSI(\(settings.rsiPeriod))")
        rsiDataSet.setColor(UIColor.systemPurple)  // Purple as requested
        rsiDataSet.lineWidth = 1.8 // Slightly thinner for cleaner look
        rsiDataSet.drawCirclesEnabled = false
        rsiDataSet.drawValuesEnabled = false
        rsiDataSet.drawFilledEnabled = false
        rsiDataSet.highlightEnabled = false // Disable tooltip for RSI line
        rsiDataSet.mode = .cubicBezier // Smooth line interpolation
        rsiDataSet.cubicIntensity = 0.1 // Subtle smoothing
        dataSets.append(rsiDataSet)
        
        // Create reference line entries spanning the chart width
        guard let firstEntry = rsiEntries.first, let lastEntry = rsiEntries.last else { return [rsiDataSet] }
        
        // Reference lines using user-configurable RSI levels
        let referenceLines = [
            (level: settings.rsiOverbought, color: UIColor.systemRed, name: "Overbought", dashPattern: [CGFloat(2.0), CGFloat(4.0)]),
            (level: 50.0, color: UIColor.systemGray, name: "Neutral", dashPattern: [CGFloat(1.0), CGFloat(3.0)]), 
            (level: settings.rsiOversold, color: UIColor.systemBlue, name: "Oversold", dashPattern: [CGFloat(2.0), CGFloat(4.0)])
        ]
        
        for referenceLine in referenceLines {
            let levelPosition = rsiBottom + (referenceLine.level / 100.0) * rsiSectionHeight
            
            // Validate reference line position is finite
            guard levelPosition.isFinite else {
                print("⚠️ Invalid reference line position: \(levelPosition) for level: \(referenceLine.level)")
                continue
            }
            
            let entries = [
                ChartDataEntry(x: firstEntry.x, y: levelPosition),
                ChartDataEntry(x: lastEntry.x, y: levelPosition)
            ]
            
            let dataSet = LineChartDataSet(entries: entries, label: "")
            dataSet.setColor(referenceLine.color.withAlphaComponent(0.6)) // Slightly more visible
            dataSet.lineWidth = referenceLine.level == 50.0 ? 0.5 : 0.7 // Thinner midline
            dataSet.drawCirclesEnabled = false
            dataSet.drawValuesEnabled = false
            dataSet.highlightEnabled = false
            dataSet.lineDashLengths = referenceLine.dashPattern
            dataSets.append(dataSet)
        }
        
        // Configure chart axis to include RSI section properly
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // CRITICAL: Validate all axis values before setting to prevent NaN errors
            let topBuffer = priceRange * 0.05
            let axisMinimum = rsiBottom
            let axisMaximum = maxPrice + topBuffer
            let granularityValue = 1.0
            
            // Validate all values are finite before setting axis properties
            guard axisMinimum.isFinite && axisMaximum.isFinite && axisMaximum > axisMinimum,
                  granularityValue.isFinite && granularityValue > 0,
                  rsiBottom.isFinite && rsiSectionHeight.isFinite && rsiSectionHeight > 0,
                  minPrice.isFinite else {
                print("⚠️ Invalid axis values detected - skipping axis configuration")
                print("axisMinimum: \(axisMinimum), axisMaximum: \(axisMaximum)")
                print("rsiBottom: \(rsiBottom), rsiSectionHeight: \(rsiSectionHeight)")
                print("minPrice: \(minPrice), maxPrice: \(maxPrice)")
                return
            }
            
            if self.autoScaleMinMaxEnabled {
                // When autoscaling, avoid forcing axis min/max; just ensure formatter handles price + RSI
                self.rightAxis.resetCustomAxisMin()
                self.rightAxis.resetCustomAxisMax()
                
                // IMPORTANT: Configure labels properly for autoscale
                self.rightAxis.labelCount = 6
                self.rightAxis.forceLabelsEnabled = false
                self.rightAxis.granularityEnabled = false
                self.rightAxis.minWidth = 60
                self.rightAxis.valueFormatter = RSISeparateAxisFormatter(
                    rsiStart: rsiBottom,
                    rsiEnd: rsiBottom + rsiSectionHeight,
                    priceStart: minPrice
                )
            } else {
                // Set axis to include both price data and RSI section
                self.rightAxis.axisMinimum = axisMinimum
                self.rightAxis.axisMaximum = axisMaximum
                
                // Disable auto-scaling to prevent zoom issues
                self.rightAxis.granularityEnabled = true
                // Dynamically compute granularity so micro-priced coins still show labels
                let span = axisMaximum - axisMinimum
                let targetTickCount = 6.0
                let rawGranularity = max(span / targetTickCount, 1e-12)
                // Round to 1-2-5 scaling for pleasant ticks
                let exponent = floor(log10(rawGranularity))
                let base = pow(10.0, exponent)
                let mantissa = rawGranularity / base
                let niceMantissa: Double
                if mantissa < 1.5 { niceMantissa = 1 }
                else if mantissa < 3.5 { niceMantissa = 2 }
                else if mantissa < 7.5 { niceMantissa = 5 }
                else { niceMantissa = 10 }
                let dynamicGranularity = niceMantissa * base
                self.rightAxis.granularity = dynamicGranularity
                self.rightAxis.labelCount = 6
                self.rightAxis.minWidth = 60
                self.rightAxis.valueFormatter = PriceFormatter()
                
                // Use custom formatter for RSI section (only if all values are valid)
                self.rightAxis.valueFormatter = RSISeparateAxisFormatter(
                    rsiStart: rsiBottom,
                    rsiEnd: rsiBottom + rsiSectionHeight,
                    priceStart: minPrice
                )
            }
        }
        
        return dataSets
    }
    
    /// Adds a visual separator line between main chart and RSI section
    private func addRSISeparatorLine(at yPosition: Double) {
        // Create a horizontal separator line
        let separatorLayer = CALayer()
        separatorLayer.backgroundColor = UIColor.separator.cgColor
        separatorLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
        
        // Convert chart coordinate to view coordinate
        let transformer = getTransformer(forAxis: .right)
        let pixelY = transformer.pixelForValues(x: 0, y: yPosition).y
        
        separatorLayer.frame.origin.y = pixelY
        layer.addSublayer(separatorLayer)
        
        // Store reference for removal later
        separatorLayer.name = "RSISeparator"
    }
    
    /// Removes existing RSI separator lines
    private func removeRSISeparatorLines() {
        layer.sublayers?.removeAll { $0.name == "RSISeparator" }
    }

    
    /// Clears all technical indicator overlays, keeping only the candlestick data
    func clearTechnicalIndicators() {
        // For candlestick charts, we'll focus on the core candlestick display
        notifyDataSetChanged()
    } 
} 
