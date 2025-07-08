//
//  ChartView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

final class ChartView: LineChartView {
    
    // MARK: - Properties for Dynamic Scrolling
    private var _allDataPoints: [Double] = []
    private var _allDates: [Date] = []
    private var _currentRange: String = "24h"
    private var _visibleDataPointsCount: Int = 50
    private var _currentScrollPosition: CGFloat = 0
    
    // Callback for when user scrolls to edges (for loading more data)
    var onScrollToEdge: ((ScrollDirection) -> Void)?
    
    enum ScrollDirection {
        case left, right
    }
    
    // Track drag state
    private var isDragging = false
    private var lastDragPosition: CGFloat = 0

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

    private func configure() {
        backgroundColor = .systemBackground
        
        // Enable scrolling and panning
        setScaleEnabled(true)
        scaleYEnabled = false
        doubleTapToZoomEnabled = false
        dragEnabled = true
        pinchZoomEnabled = false
        legend.enabled = false

        // Highlight settings
        highlightPerTapEnabled = true
        highlightPerDragEnabled = false // Disable to prevent conflicts with scrolling
        highlightValue(nil)

        // Y-Axis configuration
        leftAxis.enabled = true
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.labelFont = .systemFont(ofSize: 10)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = .systemGray5
        leftAxis.gridLineWidth = 0.5
        leftAxis.drawAxisLineEnabled = false
        leftAxis.valueFormatter = PriceFormatter()
        leftAxis.labelCount = 6
        leftAxis.granularityEnabled = false
        leftAxis.forceLabelsEnabled = false
        leftAxis.minWidth = 60
        rightAxis.enabled = false

        // X-Axis configuration
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = .secondaryLabel
        xAxis.drawGridLinesEnabled = false
        xAxis.drawAxisLineEnabled = false
        xAxis.labelFont = .systemFont(ofSize: 10)
        xAxis.granularity = 1
        xAxis.valueFormatter = DateValueFormatter()

        // Padding
        setViewPortOffsets(left: 70, top: 20, right: 20, bottom: 40)

        // Marker
        let marker = BalloonMarker(color: .tertiarySystemBackground,
                                   font: .systemFont(ofSize: 12),
                                   textColor: .label,
                                   insets: UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6))
        marker.chartView = self
        marker.setMinimumSize(CGSize(width: 60, height: 30))
        self.marker = marker
        
        // Smooth scrolling
        dragDecelerationEnabled = true
        dragDecelerationFrictionCoef = 0.92
    }
    
    // MARK: - Public Methods
    
    func update(with dataPoints: [Double], range: String) {
        guard !dataPoints.isEmpty else { return }
        
        self._allDataPoints = dataPoints
        self._currentRange = range
        
        // Calculate visible points based on range
        self._visibleDataPointsCount = calculateVisiblePoints(for: range)
        
        // Generate dates for all data points
        generateDates(for: dataPoints, range: range)
        
        // Reset to show most recent data
        self._currentScrollPosition = 0
        
        // Update chart with all data but set visible range
        updateChart()
    }
    
    private func calculateVisiblePoints(for range: String) -> Int {
        switch range {
        case "24h": return min(24, _allDataPoints.count)
        case "7d": return min(50, _allDataPoints.count)
        case "30d": return min(60, _allDataPoints.count)
        case "365d": return min(100, _allDataPoints.count)
        default: return min(50, _allDataPoints.count)
        }
    }
    
    private func generateDates(for dataPoints: [Double], range: String) {
        let now = Date()
        let timeInterval: TimeInterval = range == "24h" ? 86400 :
                                         range == "7d" ? 604800 :
                                         range == "30d" ? 2592000 : 31536000
        let start = now.addingTimeInterval(-timeInterval)
        let step = timeInterval / Double(dataPoints.count)
        
        self._allDates = (0..<dataPoints.count).map { i in
            start.addingTimeInterval(Double(i) * step)
        }
    }
    
    private func updateChart() {
        guard !_allDataPoints.isEmpty, !_allDates.isEmpty else { return }
        
        // Create entries for all data points
        let entries = zip(_allDates, _allDataPoints).map { date, value in
            ChartDataEntry(x: date.timeIntervalSince1970, y: value)
        }
        
        // Calculate Y-axis range for all data
        guard let minY = _allDataPoints.min(),
              let maxY = _allDataPoints.max() else { return }
        
        let range = maxY - minY
        let buffer = range * 0.05
        leftAxis.axisMinimum = minY - buffer
        leftAxis.axisMaximum = maxY + buffer
        
        // Determine line color based on first and last points
        let firstPrice = _allDataPoints.first ?? 0
        let lastPrice = _allDataPoints.last ?? 0
        let isPositive = lastPrice >= firstPrice
        let lineColor = isPositive ? UIColor.systemGreen : UIColor.systemRed
        
        // Create data set
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
        
        let gradientColors = [lineColor.withAlphaComponent(0.3).cgColor,
                              lineColor.withAlphaComponent(0.0).cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        
        self.data = LineChartData(dataSet: dataSet)
        
        // Set the visible range (this is key for scrolling)
        let visibleRange = Double(_visibleDataPointsCount)
        let totalTimeRange = entries.last!.x - entries.first!.x
        let visibleTimeRange = totalTimeRange * (visibleRange / Double(_allDataPoints.count))
        
        setVisibleXRangeMaximum(visibleTimeRange)
        setVisibleXRangeMinimum(visibleTimeRange)
        
        // Move to the most recent data initially
        moveViewToX(entries.last?.x ?? 0)
        
        // Update date formatter
        if let xAxisFormatter = xAxis.valueFormatter as? DateValueFormatter {
            xAxisFormatter.updateDates(_allDates)
        }
        
        notifyDataSetChanged()
        
        // Animate only on initial load
        animate(xAxisDuration: 0.6, yAxisDuration: 0.6, easingOption: .easeInOutQuart)
    }
    
    // MARK: - Scrolling Methods
    
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
        let pointWidth = dataRange / Double(_allDataPoints.count)
        let offsetX = Double(points) * pointWidth
        
        let newCenterX = currentCenterX + offsetX
        let clampedX = max(data.xMin, min(data.xMax, newCenterX))
        moveViewToX(clampedX)
    }
    
    private func checkEdgeScrolling(centerX: Double, dataRange: Double) {
        let edgeThreshold = dataRange * 0.1 // 10% of data range
        
        if centerX <= data?.xMin ?? 0 + edgeThreshold {
            onScrollToEdge?(.left)
        } else if centerX >= (data?.xMax ?? 0) - edgeThreshold {
            onScrollToEdge?(.right)
        }
    }
}

// MARK: - ChartViewDelegate Extension

extension ChartView: ChartViewDelegate {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Show marker and auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            chartView.highlightValue(nil)
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        chartView.highlightValue(nil)
    }
    
    func chartViewDidEndPanning(_ chartView: ChartViewBase) {
        // Check if we're at the edges after panning stops
        guard let lineChart = chartView as? LineChartView,
              let data = lineChart.data else { return }
        
        let lowestVisibleX = lineChart.lowestVisibleX
        let highestVisibleX = lineChart.highestVisibleX
        
        // Check if we're near the beginning (oldest data)
        if lowestVisibleX <= data.xMin + (data.xMax - data.xMin) * 0.1 {
            onScrollToEdge?(.left)
        }
        
        // Check if we're near the end (newest data)
        if highestVisibleX >= data.xMax - (data.xMax - data.xMin) * 0.1 {
            onScrollToEdge?(.right)
        }
    }
}
