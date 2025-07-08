//
//  SparklineView.swift
//  CryptoApp
//
//  Created by Assistant on 1/7/25.
//

import UIKit

class SparklineView: UIView {
    
    private var dataPoints: [Double] = []
    private var isPositiveChange: Bool = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        contentMode = .redraw
    }
    
    func configure(with dataPoints: [Double], isPositive: Bool) {
        self.dataPoints = dataPoints
        self.isPositiveChange = isPositive
        setNeedsDisplay()
    }
    
    @objc func configureWith(_ dataPoints: [NSNumber], isPositive: Bool) {
        let doubleArray = dataPoints.map { $0.doubleValue }
        configure(with: doubleArray, isPositive: isPositive)
    }
    
    // This is where the UIBezierPath plots the sparkline based on the values
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard dataPoints.count > 1 else { return }
        
        let context = UIGraphicsGetCurrentContext()
        context?.clear(rect)
        
        // Set line color based on positive/negative change
        let lineColor = isPositiveChange ? UIColor.systemGreen : UIColor.systemRed
        context?.setStrokeColor(lineColor.cgColor)
        context?.setLineWidth(2.0)
        context?.setLineCap(.round)
        context?.setLineJoin(.round)
        
        // Calculate min and max values for scaling
        let minValue = dataPoints.min() ?? 0
        let maxValue = dataPoints.max() ?? 0
        let valueRange = maxValue - minValue
        
        // Avoid division by zero
        guard valueRange > 0 else { return }
        
        // Calculate points
        let stepX = rect.width / CGFloat(dataPoints.count - 1)
        let path = UIBezierPath()
        
        for (index, value) in dataPoints.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedValue = (value - minValue) / valueRange
            let y = rect.height - (CGFloat(normalizedValue) * rect.height)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Draw the path
        context?.addPath(path.cgPath)
        context?.strokePath()
        
        // Add a subtle gradient fill
        drawGradientFill(context: context, path: path, rect: rect, color: lineColor)
    }
    
    private func drawGradientFill(context: CGContext?, path: UIBezierPath, rect: CGRect, color: UIColor) {
        guard let context = context else { return }
        
        // Create a copy of the path and close it to the bottom
        let fillPath = path.copy() as! UIBezierPath
        fillPath.addLine(to: CGPoint(x: rect.width, y: rect.height))
        fillPath.addLine(to: CGPoint(x: 0, y: rect.height))
        fillPath.close()
        
        // Create gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            color.withAlphaComponent(0.3).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) else { return }
        
        // Save context state
        context.saveGState()
        
        // Add the fill path to the context and clip
        context.addPath(fillPath.cgPath)
        context.clip()
        
        // Draw the gradient
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height), options: [])
        
        // Restore context state
        context.restoreGState()
    }
}

extension SparklineView {
    
    // Generates sample sparkline data based on percentage change
    // This simulates historical price movement leading to the current change
    static func generateSampleData(for percentChange: Double, points: Int = 20) -> [Double] {
        var dataPoints: [Double] = []
        let baseValue = 100.0 // Every graph starts from a base price of 100.0.
        
        
        // Generate realistic price movement
        var currentValue = baseValue
        dataPoints.append(currentValue)
        
        // Create a trend that leads to the final percentage change
        // If percentChange is +5%, target is 105.0
        // If it's -2%, target is 98.0
        let targetValue = baseValue + (baseValue * percentChange / 100.0)
        let totalChange = targetValue - baseValue
        
        for i in 1..<points {
            //progress gives a smooth transition from base to target.
            let progress = Double(i) / Double(points - 1)
            
            // randomFactor adds slight zig-zag noise to look like a real chart.
            let randomFactor = Double.random(in: -0.02...0.02)
            let trendValue = baseValue + (totalChange * progress) + (baseValue * randomFactor)
            
            // Add some volatility
            let volatility = abs(percentChange) * 0.1
            let noise = Double.random(in: -volatility...volatility)
            currentValue = trendValue + noise
            
            // Ensures the last point accurately reflects the 24h % change.
            dataPoints.append(currentValue)
        }
        
        // Ensure the last point reflects the actual percentage change
        dataPoints[dataPoints.count - 1] = targetValue
        
        return dataPoints
    }
}
