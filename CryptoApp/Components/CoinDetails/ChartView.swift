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

        // General Interaction Settings
        setScaleEnabled(true)
        scaleYEnabled = false
        doubleTapToZoomEnabled = false
        dragEnabled = true
        pinchZoomEnabled = false
        legend.enabled = false

        // Highlight Behavior
        highlightPerTapEnabled = true
        highlightPerDragEnabled = false
        highlightValue(nil)
        
        // Y-axis Price
        leftAxis.enabled = true
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.labelFont = .systemFont(ofSize: 10)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = .systemGray5
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawAxisLineEnabled = false
        leftAxis.valueFormatter = PriceFormatter()
        leftAxis.labelCount = 6
        leftAxis.minWidth = 60
        
        // Disable right axis
        rightAxis.enabled = false

        // X axis - Time / Date
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelFont = .systemFont(ofSize: 10)
        xAxis.granularity = 1
        xAxis.valueFormatter = DateValueFormatter()

        
        // Add padding to chart edges
        setViewPortOffsets(left: 70, top: 20, right: 20, bottom: 40)

        
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
    }

    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFadingEdges()
        layoutHintLabel()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showHintLabel()
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

    func update(with dataPoints: [Double], range: String) {
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
        case "365d": return min(100, allDataPoints.count)
        default: return min(50, allDataPoints.count)
        }
    }

    private func generateDates(for dataPoints: [Double], range: String) {
        let now = Date()
        let timeInterval: TimeInterval = range == "24h" ? 86400 :
                                         range == "7d" ? 604800 :
                                         range == "30d" ? 2592000 : 31536000
        let start = now.addingTimeInterval(-timeInterval)
        let step = timeInterval / Double(dataPoints.count)
        
        // Generate evenly spaced dates
        self.allDates = (0..<dataPoints.count).map { i in
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

        // Setup y-axis buffer
        let range = maxY - minY
        let buffer = range * 0.05
        leftAxis.axisMinimum = minY - buffer
        leftAxis.axisMaximum = maxY + buffer

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

        // Update x-axis formatter with new dates
        if let xAxisFormatter = xAxis.valueFormatter as? DateValueFormatter {
            xAxisFormatter.updateDates(allDates)
        }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            chartView.highlightValue(nil)
        }
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartView.highlightValue(nil)
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
