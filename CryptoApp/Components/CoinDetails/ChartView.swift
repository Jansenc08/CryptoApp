//
//  ChartView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

final class ChartView: LineChartView {

    // MARK: - Properties
    
    // Holds raw data points and timestamps
    private var allDataPoints: [Double] = []
    private var allDates: [Date] = []
    private var currentRange: String = "24h"
    private var visibleDataPointsCount: Int = 50
    private var currentScrollPosition: CGFloat = 0

    // Common chart functionality helper
    private let configurationHelper = ChartConfigurationHelper()
    
    // MARK: - Label Management
    private var labelManager: ChartLabelManager?

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
        setupLabelManager()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
        configure()
        setupLabelManager()
    }
    
    private func setupLabelManager() {
        labelManager = ChartLabelManager(parentChart: self)
    }

    // MARK: -Chart Setup
    private func configure() {
        // Use helper for basic configuration
        ChartConfigurationHelper.configureBasicSettings(for: self)
        ChartConfigurationHelper.configureAxes(for: self)
        
        // Line chart specific settings
        scaleYEnabled = true  // Allow Y-axis zoom for price analysis
        
        // Set zoom limits for better UX
        setVisibleXRangeMaximum(200)  // Max zoom out
        setVisibleXRangeMinimum(5)    // Max zoom in (show 5 data points)
        
        // Add gesture recognizers using helper
        configurationHelper.addZoomGestures(to: self, target: self, resetAction: #selector(resetChartZoom), showZoomAction: #selector(showZoomHint))

        
        // Add padding to chart edges (adjusted for right-side Y-axis)
        setViewPortOffsets(left: 20, top: 20, right: 70, bottom: 40)

        
        // Tooltip marker when tapping a point in the chart
        let marker = BalloonMarker(color: .tertiarySystemBackground,
                                   font: .systemFont(ofSize: 12),
                                   textColor: .label,
                                   insets: UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6))
        marker.chartView = self
        marker.setMinimumSize(CGSize(width: 60, height: 30))
        self.marker = marker

        // enable smooth dragging in the chart
        dragDecelerationEnabled = true
        dragDecelerationFrictionCoef = 0.92

        // Set up visual effects using helper
        configurationHelper.addFadingEdges(to: self)
        configurationHelper.addScrollHintLabel(to: self)
    }
    

    
    @objc private func resetChartZoom() {
        // Animate back to fit all data
        fitScreen()
        
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
    
    private func showZoomIndicator() {
        // Create temporary zoom level indicator
        let zoomLabel = UILabel()
        zoomLabel.text = "🔍 Zoom: \(String(format: "%.1fx", scaleX))"
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
            zoomLabel.widthAnchor.constraint(equalToConstant: 120),
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
        let dataCount = allDataPoints.count
        
        // Calculate optimal visible points based on range
        let optimalVisiblePoints: Double
        switch currentRange {
        case "24h": optimalVisiblePoints = min(24, Double(dataCount))  // Show hourly points
        case "7d": optimalVisiblePoints = min(35, Double(dataCount))   // Show ~week view
        case "30d": optimalVisiblePoints = min(60, Double(dataCount))  // Show ~month view
        case "All": optimalVisiblePoints = min(100, Double(dataCount)) // Show broader view
        default: optimalVisiblePoints = min(50, Double(dataCount))
        }
        
        // Apply the zoom
        setVisibleXRangeMaximum(optimalVisiblePoints)
        
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

    func update(_ dataPoints: [Double], range: String) {
        guard !dataPoints.isEmpty else { return }

        self.allDataPoints = dataPoints
        self.currentRange = range
        self.visibleDataPointsCount = ChartConfigurationHelper.calculateVisiblePoints(for: range, dataCount: dataPoints.count)
        generateDates(for: dataPoints, range: range)
        self.currentScrollPosition = 0
        updateChart()
    }



    private func generateDates(for dataPoints: [Double], range: String) {
        let now = Date()
        
        let timeInterval: TimeInterval = range == "24h" ? 86400 :
                                         range == "7d" ? 604800 :
                                         range == "30d" ? 2592000 : 31536000
        let start = now.addingTimeInterval(-timeInterval)
        
        let step = timeInterval / Double(dataPoints.count - 1)
        allDates = (0..<dataPoints.count).map { i in
            start.addingTimeInterval(Double(i) * step)
        }
    }

    // MARK: - Chart Rendering

    private func updateChart() {
        guard !allDataPoints.isEmpty, !allDates.isEmpty else { return }

        // Combine data and dates into chart entries, filtering out any NaN values
        let entries = zip(allDates, allDataPoints).compactMap { date, value -> ChartDataEntry? in
            guard value.isFinite else { return nil }
            return ChartDataEntry(x: date.timeIntervalSince1970, y: value)
        }
        
        guard !entries.isEmpty else { return }

        guard let minY = allDataPoints.min(), let maxY = allDataPoints.max() else { return }

        // Setup y-axis buffer (using right axis)
        let range = maxY - minY
        // FIXED: Prevent NaN in CoreGraphics when all values are identical
        let fallbackRange = max(abs(maxY), 1.0) * 0.01 // Fallback for zero/near-zero prices
        let minRange = max(range, fallbackRange) // Ensure at least 1% range
        let buffer = minRange * 0.05
        rightAxis.axisMinimum = minY - buffer
        rightAxis.axisMaximum = maxY + buffer

        // Color based on price trend
        // Green if lastprice >= firstPrice(Positive) else red.
        let firstPrice = allDataPoints.first ?? 0
        let lastPrice = allDataPoints.last ?? 0
        let isPositive = lastPrice >= firstPrice
        let lineColor = isPositive ? UIColor.systemGreen : UIColor.systemRed

        // Setup dataset
        let dataSet = LineChartDataSet(entries: entries, label: "")
        dataSet.drawCirclesEnabled = false
        dataSet.mode = .cubicBezier
        dataSet.lineWidth = 2.5
        dataSet.setColor(lineColor)
        dataSet.drawValuesEnabled = false
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 1.0
        dataSet.highlightColor = lineColor.withAlphaComponent(0.8)
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = true

        // Fill gradient
        let gradientColors = [lineColor.withAlphaComponent(0.3).cgColor,
                              lineColor.withAlphaComponent(0.0).cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)

        self.data = LineChartData(dataSet: dataSet)

        // Adjust visible time range
        let visibleRange = Double(visibleDataPointsCount)
        let totalTimeRange = entries.last!.x - entries.first!.x
        let visibleTimeRange = totalTimeRange * (visibleRange / Double(allDataPoints.count))

        setVisibleXRangeMaximum(visibleTimeRange)
        setVisibleXRangeMinimum(visibleTimeRange)
        
        // Scroll to the latest entry
        moveViewToX(entries.last?.x ?? 0)

        // Update x-axis formatter with new dates and range
        if let xAxisFormatter = xAxis.valueFormatter as? DateValueFormatter {
            xAxisFormatter.updateDates(allDates)
            xAxisFormatter.updateRange(currentRange)
        }
        
        // Update marker with current range for proper tooltip display
        if let balloonMarker = self.marker as? BalloonMarker {
            balloonMarker.updateRange(currentRange)
        }

        // Set intelligent initial zoom based on data range
        setInitialZoom()

        notifyDataSetChanged()
        animate(xAxisDuration: 0.6, yAxisDuration: 0.6, easingOption: .easeInOutQuart)
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
        let pointWidth = dataRange / Double(allDataPoints.count)
        let offsetX = Double(points) * pointWidth
        
        let newCenterX = currentCenterX + offsetX
        let clampedX = max(data.xMin, min(data.xMax, newCenterX))
        moveViewToX(clampedX)
    }
    

}

// MARK: - Delegate Handling

extension ChartView: ChartViewDelegate {
    
    // Auto-clear highlight tooltip after delay
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak chartView] in
            chartView?.highlightValue(nil)
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartView.highlightValue(nil)
    }
    
    // MARK: - Zoom Event Handling
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        // Provide subtle haptic feedback during zoom
        if abs(scaleX - 1.0) > 0.1 || abs(scaleY - 1.0) > 0.1 {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
        
        // Log zoom level for debugging
        // Chart zoom level changed
    }
    
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        // Handle chart panning while zoomed
        // This ensures smooth interaction between zoom and pan
    }

    // Detect if user has panned all the way to left/right
    func chartViewDidEndPanning(_ chartView: ChartViewBase) {
        guard let lineChart = chartView as? LineChartView,
              let data = lineChart.data else { return }

        let lowestVisibleX = lineChart.lowestVisibleX
        let highestVisibleX = lineChart.highestVisibleX

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

extension ChartView {
    
    func updateLineThickness(_ thickness: CGFloat) {
        guard let dataSet = data?.dataSets.first as? LineChartDataSet else { return }
        
        // Preserve viewport state
        let savedScaleX = scaleX
        let savedScaleY = scaleY
        let savedCenterX = (lowestVisibleX + highestVisibleX) / 2
        let savedCenterY = (rightAxis.axisMinimum + rightAxis.axisMaximum) / 2
        
        dataSet.lineWidth = thickness
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
        guard let dataSet = data?.dataSets.first as? LineChartDataSet else { return }
        
        // Preserve viewport state
        let savedScaleX = scaleX
        let savedScaleY = scaleY
        let savedCenterX = (lowestVisibleX + highestVisibleX) / 2
        let savedCenterY = (rightAxis.axisMinimum + rightAxis.axisMaximum) / 2
        
        // Determine if current trend is positive or negative
        let firstPrice = allDataPoints.first ?? 0
        let lastPrice = allDataPoints.last ?? 0
        let isPositive = lastPrice >= firstPrice
        
        let color = isPositive ? theme.positiveColor : theme.negativeColor
        
        dataSet.setColor(color)
        dataSet.highlightColor = color.withAlphaComponent(0.8)
        
        // Update gradient fill
        let gradientColors = [color.withAlphaComponent(0.3).cgColor,
                              color.withAlphaComponent(0.0).cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        
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

extension ChartView {
    
    /// Updates chart with technical indicators overlays
    func updateWithTechnicalIndicators(_ settings: TechnicalIndicators.IndicatorSettings, theme: ChartColorTheme = .classic) {
        guard !allDataPoints.isEmpty else { return }
        
        // Clear existing additional datasets (keep main price line)
        let existingData = data
        var dataSets: [ChartDataSet] = []
        
        // Keep the main price dataset (first one)
        if let priceDataSet = existingData?.dataSets.first as? ChartDataSet {
            dataSets.append(priceDataSet)
        }
        
        // Store data sets for label updates
        var smaDataSet: LineChartDataSet?
        var emaDataSet: LineChartDataSet?
        var rsiResult: TechnicalIndicators.RSIResult?
        
        // Add moving averages if enabled
        if settings.showSMA {
            smaDataSet = createSMADataSet(period: settings.smaPeriod, theme: theme)
            if let sma = smaDataSet {
                dataSets.append(sma)
            }
        }
        
        if settings.showEMA {
            emaDataSet = createEMADataSet(period: settings.emaPeriod, theme: theme)
            if let ema = emaDataSet {
                dataSets.append(ema)
            }
        }
        
        // Add RSI if enabled (with reference lines)
        if settings.showRSI {
            rsiResult = TechnicalIndicators.calculateRSI(prices: allDataPoints, period: settings.rsiPeriod)
            let rsiDataSets = createRSIDataSets(period: settings.rsiPeriod, theme: theme)
            // SAFETY: Only append if we have valid data sets
            if !rsiDataSets.isEmpty {
                dataSets.append(contentsOf: rsiDataSets)
            }
        }
        
        // Update chart with all datasets
        // SAFETY: Validate all data sets have entries before creating LineChartData
        let validDataSets = dataSets.filter { !$0.entries.isEmpty }
        if !validDataSets.isEmpty {
            self.data = LineChartData(dataSets: validDataSets)
            notifyDataSetChanged()
            
            // Calculate RSI area coordinates for label positioning
            let chartHeight = self.bounds.height
            let rsiAreaTop = chartHeight * 0.75  // RSI section starts at 75% down
            let rsiAreaHeight = chartHeight * 0.25  // RSI section is 25% of chart height
            
            // Update labels with current values
            labelManager?.updateAllLabels(
                smaDataSet: smaDataSet,
                emaDataSet: emaDataSet,
                rsiResult: rsiResult,
                settings: settings,
                theme: theme,
                rsiAreaTop: rsiAreaTop,
                rsiAreaHeight: rsiAreaHeight
            )
        }
    }
    
    private func createSMADataSet(period: Int, theme: ChartColorTheme) -> LineChartDataSet? {
        let smaResult = TechnicalIndicators.calculateSMA(prices: allDataPoints, period: period)
        
        let entries = smaResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value, index < allDates.count else { return nil }
            // Additional NaN check for safety
            guard value.isFinite else { return nil }
            return ChartDataEntry(x: allDates[index].timeIntervalSince1970, y: value)
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
    
    private func createEMADataSet(period: Int, theme: ChartColorTheme) -> LineChartDataSet? {
        let emaResult = TechnicalIndicators.calculateEMA(prices: allDataPoints, period: period)
        
        let entries = emaResult.values.enumerated().compactMap { index, value -> ChartDataEntry? in
            guard let value = value, index < allDates.count else { return nil }
            // Additional NaN check for safety
            guard value.isFinite else { return nil }
            return ChartDataEntry(x: allDates[index].timeIntervalSince1970, y: value)
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
    

    
    private func createRSIDataSets(period: Int, theme: ChartColorTheme) -> [LineChartDataSet] {
        // SAFETY: Early validation to prevent crashes
        guard !allDataPoints.isEmpty, allDataPoints.count > period else { return [] }
        guard !allDates.isEmpty, allDates.count == allDataPoints.count else { return [] }
        
        // No RSI display on line chart - only candlestick chart shows RSI
        return []
    }
    

    
    /// Clears all technical indicator overlays, keeping only the main price line
    func clearTechnicalIndicators() {
        guard let existingData = data,
              let priceDataSet = existingData.dataSets.first else { return }
        
        // Keep only the first dataset (main price line)
        self.data = LineChartData(dataSet: priceDataSet)
        notifyDataSetChanged()
    }
    
    /// Gets the main price dataset for modifications
    private func getMainPriceDataSet() -> LineChartDataSet? {
        return data?.dataSets.first as? LineChartDataSet
    }
}
