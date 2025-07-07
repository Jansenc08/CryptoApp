//
//  ChartView.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

final class ChartView: LineChartView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = nil 
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        delegate = nil
        backgroundColor = .systemBackground
        setScaleEnabled(true)
        scaleYEnabled = false
        doubleTapToZoomEnabled = false
        dragEnabled = true
        pinchZoomEnabled = true
        legend.enabled = false

        highlightPerTapEnabled = true
        highlightPerDragEnabled = true
        highlightValue(nil)

        // Y-Axis
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

        // X-Axis
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
    }
    
    func update(with dataPoints: [Double], range: String) {
        guard !dataPoints.isEmpty else { return }

        let now = Date()
        let timeInterval: TimeInterval = range == "24h" ? 86400 :
                                         range == "7d" ? 604800 :
                                         range == "30d" ? 2592000 : 31536000
        let start = now.addingTimeInterval(-timeInterval)
        let step = timeInterval / Double(dataPoints.count)
        let dates = (0..<dataPoints.count).map { i in
            start.addingTimeInterval(Double(i) * step)
        }

        let entries = zip(dates, dataPoints).map { date, value in
            ChartDataEntry(x: date.timeIntervalSince1970, y: value)
        }

        guard let minY = entries.map({ $0.y }).min(),
              let maxY = entries.map({ $0.y }).max() else { return }

        let range = maxY - minY
        let buffer = range * 0.05
        leftAxis.axisMinimum = minY - buffer
        leftAxis.axisMaximum = maxY + buffer

        let firstPrice = dataPoints.first ?? 0
        let lastPrice = dataPoints.last ?? 0
        let isPositive = lastPrice >= firstPrice
        let lineColor = isPositive ? UIColor.systemGreen : UIColor.systemRed

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

        if let xAxisFormatter = xAxis.valueFormatter as? DateValueFormatter {
            xAxisFormatter.updateDates(dates)
        }

        notifyDataSetChanged()
        animate(xAxisDuration: 0.8, yAxisDuration: 0.8, easingOption: .easeInOutQuart)
    }

}
