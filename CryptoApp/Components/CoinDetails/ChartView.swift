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

    // Fading edge layers for viual vue
    private let leftFade = CAGradientLayer()
    private let rightFade = CAGradientLayer()
    
    // Scroll hint UI elements
    private let scrollHintLabel = UILabel()
    private let arrowNudgeView = UIImageView()
    private var hintHasShown = false

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

    // MARK: -Chart Setup
    private func configure() {
        backgroundColor = .systemBackground

        // Enhanced Interaction Settings with Zoom
        setScaleEnabled(true)
        scaleYEnabled = true  // Allow Y-axis zoom for price analysis
        doubleTapToZoomEnabled = true  // Double-tap to zoom in/out
        dragEnabled = true
        pinchZoomEnabled = true  // Pinch to zoom
        legend.enabled = false
        
        // Set zoom limits for better UX
        setVisibleXRangeMaximum(200)  // Max zoom out
        setVisibleXRangeMinimum(5)    // Max zoom in (show 5 data points)

        // Highlight Behavior
        highlightPerTapEnabled = true
        highlightPerDragEnabled = false
        highlightValue(nil)
        
        // Add zoom gesture recognizers
        addZoomGestures()
        
        // Disable left axis
        leftAxis.enabled = false
        
        // Y-axis Price (moved to right side)
        rightAxis.enabled = true
        rightAxis.labelTextColor = .secondaryLabel
        rightAxis.labelFont = .systemFont(ofSize: 10)
        rightAxis.drawGridLinesEnabled = true
        rightAxis.gridColor = .systemGray5
        rightAxis.gridLineWidth = 0.5
        rightAxis.drawAxisLineEnabled = false
        rightAxis.valueFormatter = PriceFormatter()
        rightAxis.labelCount = 6
        rightAxis.minWidth = 60

        // X axis - Time / Date
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelFont = .systemFont(ofSize: 10)
        xAxis.granularity = 1
        xAxis.valueFormatter = DateValueFormatter()

        
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

        addFadingEdges()
        addScrollHintLabel()
        
        // Ensure gradients are properly set for current appearance
        updateFadingEdgeColors()
    }
    
    // MARK: - Zoom Gestures
    
    private func addZoomGestures() {
        // Triple-tap to reset zoom
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(resetChartZoom))
        tripleTapGesture.numberOfTapsRequired = 3
        addGestureRecognizer(tripleTapGesture)
        
        // Long press to show zoom controls
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(showZoomControls(_:)))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
    }
    
    @objc private func resetChartZoom() {
        // Animate back to fit all data
        fitScreen()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        AppLogger.chart("Chart zoom reset")
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
        
        AppLogger.chart("Line chart initial zoom: showing \(Int(optimalVisiblePoints)) of \(dataCount) points")
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFadingEdges()
        layoutHintLabel()
    }
    
    // MARK: - Dark Mode Support
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update gradient colors when appearance changes
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateFadingEdgeColors()
            
            // Force background color update
            backgroundColor = .systemBackground
        }
    }
    
    private func updateFadingEdgeColors() {
        // Update left gradient colors
        leftFade.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor
        ]
        
        // Update right gradient colors  
        rightFade.colors = [
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor,
            UIColor.systemBackground.cgColor
        ]
    }

    // MARK: - Fading Edges

    private func addFadingEdges() {
        // Left gradient
        leftFade.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor
        ]
        
        leftFade.startPoint = CGPoint(x: 0, y: 0.5)
        leftFade.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(leftFade)

        // Right gradient
        rightFade.colors = [
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor,
            UIColor.systemBackground.cgColor
        ]
        
        rightFade.startPoint = CGPoint(x: 0, y: 0.5)
        rightFade.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(rightFade)
    }

    private func layoutFadingEdges() {
        let fadeWidth: CGFloat = 20
        leftFade.frame = CGRect(x: 0, y: 0, width: fadeWidth, height: bounds.height)
        rightFade.frame = CGRect(x: bounds.width - fadeWidth, y: 0, width: fadeWidth, height: bounds.height)
    }

    // MARK: - Hint Label

    // Animated hint
    private func addScrollHintLabel() {
        scrollHintLabel.text = "← Swipe to explore chart →"
        scrollHintLabel.textAlignment = .center
        scrollHintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        scrollHintLabel.textColor = .secondaryLabel
        scrollHintLabel.alpha = 0
        scrollHintLabel.backgroundColor = .clear
        scrollHintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollHintLabel)

        // Animated arrow
        let arrowImage = UIImage(systemName: "arrow.right")?.withRenderingMode(.alwaysTemplate)
        arrowNudgeView.image = arrowImage
        arrowNudgeView.tintColor = .systemBlue
        arrowNudgeView.contentMode = .scaleAspectFit
        arrowNudgeView.alpha = 0.0
        addSubview(arrowNudgeView)

        // Show animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showHintLabel()
        }
    }

    private func layoutHintLabel() {
        scrollHintLabel.frame = CGRect(
            x: 0,
            y: bounds.height - 24,
            width: bounds.width,
            height: 20
        )
        ChartScrollHintAnimator.layoutArrow(arrowNudgeView, in: bounds)
    }

    private func showHintLabel() {
        guard !hintHasShown else { return }
        hintHasShown = true

        ChartScrollHintAnimator.fadeIn(label: scrollHintLabel, arrow: arrowNudgeView)
        ChartScrollHintAnimator.animateBounce(for: arrowNudgeView)
        ChartScrollHintAnimator.fadeOut(label: scrollHintLabel, arrow: arrowNudgeView)
    }

    // MARK: - Public Update Method

    func update(_ dataPoints: [Double], range: String) {
        guard !dataPoints.isEmpty else { return }

        self.allDataPoints = dataPoints
        self.currentRange = range
        self.visibleDataPointsCount = calculateVisiblePoints(for: range)
        generateDates(for: dataPoints, range: range)
        self.currentScrollPosition = 0
        updateChart()
    }

    private func calculateVisiblePoints(for range: String) -> Int {
        switch range {
        case "24h": return min(24, allDataPoints.count)
        case "7d": return min(50, allDataPoints.count)
        case "30d": return min(60, allDataPoints.count)
        case "All", "365d": return min(100, allDataPoints.count)
        default: return min(50, allDataPoints.count)
        }
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

        // Combine data and dates into chart entries
        let entries = zip(allDates, allDataPoints).map { date, value in
            ChartDataEntry(x: date.timeIntervalSince1970, y: value)
        }

        guard let minY = allDataPoints.min(), let maxY = allDataPoints.max() else { return }

        // Setup y-axis buffer (using right axis)
        let range = maxY - minY
        let buffer = range * 0.05
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
        AppLogger.chart("Line chart zoom: X=\(String(format: "%.2f", scaleX)), Y=\(String(format: "%.2f", scaleY))")
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
