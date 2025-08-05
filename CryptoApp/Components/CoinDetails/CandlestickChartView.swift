//
//  CandlestickChartView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

final class CandlestickChartView: CandleStickChartView {
    
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
        // Use helper for basic configuration
        ChartConfigurationHelper.configureBasicSettings(for: self)
        ChartConfigurationHelper.configureAxes(for: self)
        
        // Candlestick chart specific settings
        scaleYEnabled = false               // Disable Y-axis zoom to maintain consistent candle proportions
        
        // Set zoom limits optimized for candlestick analysis
        setVisibleXRangeMaximum(200)        // Max zoom out (show 200 candles) - increased for monthly/all views
        setVisibleXRangeMinimum(3)          // Max zoom in (show 3 candles for detail)
        
        // Add gesture recognizers using helper
        configurationHelper.addZoomGestures(to: self, target: self, resetAction: #selector(resetCandlestickZoom), showZoomAction: #selector(showZoomHint))
        
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
        
        AppLogger.chart("Candlestick chart zoom reset with consistent Y-axis")
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
        
        AppLogger.chart("Candlestick initial zoom: showing \(Int(optimalVisibleCandles)) of \(dataCount) candles")
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
        
        // Create candlestick entries using INTEGER indices instead of timestamps
        let entries = allOHLCData.enumerated().map { index, ohlc in
            CandleChartDataEntry(x: Double(index),  // X-axis position
                               shadowH: ohlc.high,  // Top wick
                               shadowL: ohlc.low,   // Bottom wick
                               open: ohlc.open,     // Open Price
                               close: ohlc.close,   // Close Price
                               icon: nil)
        }
        
        guard let minY = allOHLCData.map({ min($0.low, min($0.open, $0.close)) }).min(),
              let maxY = allOHLCData.map({ max($0.high, max($0.open, $0.close)) }).max() else { return }
        
        // Setup y-axis with LARGER range to make candles appear smaller
        let range = maxY - minY
        let buffer = range * 0.25  // Much larger buffer to create more price context
        
        // Show wider price range
        rightAxis.axisMinimum = minY - buffer
        rightAxis.axisMaximum = maxY + buffer
        
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
        
        let chartData = CandleChartData(dataSet: dataSet)
        self.data = chartData
        
        // Force immediate render
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
        layoutIfNeeded()
        
        // Set intelligent initial zoom based on range and data
        setInitialZoom()
        
        AppLogger.chart("Candlestick chart updated with \(allOHLCData.count) candles")
        
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
            AppLogger.chart("Candlestick selected: \(isBullish ? "📈" : "📉") O:\(String(format: "%.0f", candleEntry.open)) C:\(String(format: "%.0f", candleEntry.close))")
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
        AppLogger.chart("Candlestick zoom: \(visibleCandles) candles visible (X-axis only)")
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
        xAxis.drawGridLinesEnabled = enabled
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
