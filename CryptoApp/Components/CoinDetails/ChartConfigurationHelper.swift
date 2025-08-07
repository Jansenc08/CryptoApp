//
//  ChartConfigurationHelper.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//

import UIKit
import DGCharts

/// Helper class to configure common chart settings for both LineChartView and CandleStickChartView
class ChartConfigurationHelper {
    
    // MARK: - Fading Edge Properties
    
    let leftFade = CAGradientLayer()
    let rightFade = CAGradientLayer()
    
    // MARK: - Scroll Hint Properties
    
    let scrollHintLabel = UILabel()
    let arrowNudgeView = UIImageView()
    var hintHasShown = false
    
    // MARK: - Common Configuration for LineChartView
    
    static func configureBasicSettings(for chartView: LineChartView) {
        chartView.backgroundColor = .systemBackground
        chartView.legend.enabled = false
        chartView.dragDecelerationEnabled = true
        chartView.dragDecelerationFrictionCoef = 0.92
        chartView.highlightPerTapEnabled = true
        chartView.highlightPerDragEnabled = false
        chartView.highlightValue(nil)
        chartView.setScaleEnabled(true)
        chartView.doubleTapToZoomEnabled = true
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = true
        chartView.setViewPortOffsets(left: 20, top: 20, right: 70, bottom: 40)
    }
    
    static func configureAxes(for chartView: LineChartView) {
        // Disable left axis
        chartView.leftAxis.enabled = false
        
        // Y-axis Price (Right side)
        chartView.rightAxis.enabled = true
        chartView.rightAxis.labelTextColor = .secondaryLabel
        chartView.rightAxis.labelFont = .systemFont(ofSize: 10)
        chartView.rightAxis.drawGridLinesEnabled = true
        chartView.rightAxis.gridColor = .systemGray5
        chartView.rightAxis.gridLineWidth = 0.5
        chartView.rightAxis.drawAxisLineEnabled = false
        chartView.rightAxis.valueFormatter = PriceFormatter()
        chartView.rightAxis.labelCount = 6
        chartView.rightAxis.minWidth = 60
        
        // X axis - Time / Date
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelTextColor = .secondaryLabel
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.drawAxisLineEnabled = false
        chartView.xAxis.labelFont = .systemFont(ofSize: 10)
        chartView.xAxis.granularity = 1
        chartView.xAxis.valueFormatter = DateValueFormatter()
    }
    
    // MARK: - Common Configuration for CandleStickChartView
    
    static func configureBasicSettings(for chartView: CandleStickChartView) {
        chartView.backgroundColor = .systemBackground
        chartView.legend.enabled = false
        chartView.dragDecelerationEnabled = true
        chartView.dragDecelerationFrictionCoef = 0.92
        chartView.highlightPerTapEnabled = true
        chartView.highlightPerDragEnabled = false
        chartView.highlightValue(nil)
        chartView.setScaleEnabled(true)
        chartView.doubleTapToZoomEnabled = true
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = true
        chartView.setViewPortOffsets(left: 20, top: 20, right: 70, bottom: 40)
    }
    
    static func configureAxes(for chartView: CandleStickChartView) {
        // Disable left axis
        chartView.leftAxis.enabled = false
        
        // Y-axis Price (Right side)
        chartView.rightAxis.enabled = true
        chartView.rightAxis.labelTextColor = .secondaryLabel
        chartView.rightAxis.labelFont = .systemFont(ofSize: 10)
        chartView.rightAxis.drawGridLinesEnabled = true
        chartView.rightAxis.gridColor = .systemGray5
        chartView.rightAxis.gridLineWidth = 0.5
        chartView.rightAxis.drawAxisLineEnabled = false
        chartView.rightAxis.valueFormatter = PriceFormatter()
        chartView.rightAxis.labelCount = 6
        chartView.rightAxis.minWidth = 60
        
        // X axis - Time / Date
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelTextColor = .secondaryLabel
        chartView.xAxis.drawGridLinesEnabled = false
        chartView.xAxis.drawAxisLineEnabled = false
        chartView.xAxis.labelFont = .systemFont(ofSize: 10)
        chartView.xAxis.granularity = 1
        chartView.xAxis.valueFormatter = DateValueFormatter()
    }
    
    // MARK: - Instance Methods for Visual Effects
    
    func addFadingEdges(to chartView: UIView) {
        // Left gradient
        leftFade.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor
        ]
        leftFade.startPoint = CGPoint(x: 0, y: 0.5)
        leftFade.endPoint = CGPoint(x: 1, y: 0.5)
        chartView.layer.addSublayer(leftFade)
        
        // Right gradient
        rightFade.colors = [
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor,
            UIColor.systemBackground.cgColor
        ]
        rightFade.startPoint = CGPoint(x: 0, y: 0.5)
        rightFade.endPoint = CGPoint(x: 1, y: 0.5)
        chartView.layer.addSublayer(rightFade)
    }
    
    func layoutFadingEdges(in bounds: CGRect) {
        let fadeWidth: CGFloat = 20
        leftFade.frame = CGRect(x: 0, y: 0, width: fadeWidth, height: bounds.height)
        rightFade.frame = CGRect(x: bounds.width - fadeWidth, y: 0, width: fadeWidth, height: bounds.height)
    }
    
    func updateFadingEdgeColors() {
        leftFade.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor
        ]
        rightFade.colors = [
            UIColor.systemBackground.withAlphaComponent(0.0).cgColor,
            UIColor.systemBackground.cgColor
        ]
    }
    
    // MARK: - Scroll Hint Methods
    
    func addScrollHintLabel(to chartView: UIView) {
        scrollHintLabel.text = "← Swipe to explore chart →"
        scrollHintLabel.textAlignment = .center
        scrollHintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        scrollHintLabel.textColor = .secondaryLabel
        scrollHintLabel.alpha = 0
        scrollHintLabel.backgroundColor = .clear
        scrollHintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Animated arrow
        let arrowImage = UIImage(systemName: "arrow.right")?.withRenderingMode(.alwaysTemplate)
        arrowNudgeView.image = arrowImage
        arrowNudgeView.tintColor = .systemBlue
        arrowNudgeView.contentMode = .scaleAspectFit
        arrowNudgeView.alpha = 0.0
        
        chartView.addSubviews(scrollHintLabel, arrowNudgeView)
        
        // Show animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showHintLabel()
        }
    }
    
    func layoutHintLabel(in bounds: CGRect) {
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
    
    // MARK: - Zoom Gesture Methods for LineChartView
    
    func addZoomGestures(to chartView: LineChartView, target: AnyObject, resetAction: Selector, showZoomAction: Selector) {
        // Triple-tap to reset zoom
        let tripleTapGesture = UITapGestureRecognizer(target: target, action: resetAction)
        tripleTapGesture.numberOfTapsRequired = 3
        chartView.addGestureRecognizer(tripleTapGesture)
        
        // Long press to show zoom controls
        let longPressGesture = UILongPressGestureRecognizer(target: target, action: showZoomAction)
        longPressGesture.minimumPressDuration = 0.5
        chartView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Zoom Gesture Methods for CandleStickChartView
    
    func addZoomGestures(to chartView: CandleStickChartView, target: AnyObject, resetAction: Selector, showZoomAction: Selector) {
        // Triple-tap to reset zoom
        let tripleTapGesture = UITapGestureRecognizer(target: target, action: resetAction)
        tripleTapGesture.numberOfTapsRequired = 3
        chartView.addGestureRecognizer(tripleTapGesture)
        
        // Long press to show zoom controls
        let longPressGesture = UILongPressGestureRecognizer(target: target, action: showZoomAction)
        longPressGesture.minimumPressDuration = 0.5
        chartView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Utility Methods
    
    static func calculateVisiblePoints(for range: String, dataCount: Int) -> Int {
        switch range {
        case "24h": return min(24, dataCount)
        case "7d": return min(50, dataCount)
        case "30d": return min(60, dataCount)
        case "All", "365d": return min(100, dataCount)
        default: return min(50, dataCount)
        }
    }
} 
