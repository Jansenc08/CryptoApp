//
//  CandlestickBalloonMarker.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 7/7/25.
//
//  Advanced tooltip for candlestick charts that displays comprehensive OHLC data
//  when users tap on individual candles.

import DGCharts
import UIKit

/**
 * CandlestickBalloonMarker creates detailed tooltips for candlestick charts showing OHLC data.
 * 
 * Key features:
 * - Displays comprehensive OHLC (Open, High, Low, Close) information
 * - Shows percentage change and trend indicators (📈/📉)
 * - Adapts time formatting based on chart range (24h = time, others = date+time)
 * - Maps index-based X values to actual dates for proper display
 * - Left-aligned text layout for better readability of multiple data points
 * - Professional styling with rounded corners and connection lines
 */
class CandlestickBalloonMarker: MarkerImage {
    
    // MARK: - Configuration Properties
    
    /// Background color of the tooltip
    private var color: UIColor
    
    /// Font for the tooltip text
    private var font: UIFont
    
    /// Text color inside the tooltip
    private var textColor: UIColor
    
    /// Padding around the tooltip content
    private var insets: UIEdgeInsets
    
    /// Minimum size constraint for the tooltip
    private var customMinimumSize = CGSize()
    
    /// Maps chart X-value indices to actual Date objects for timestamp display
    private var dateMap: [Date] = []
    
    /// Current time range filter that affects date/time formatting
    private var currentRange: String = "24h"
    
    // MARK: - Internal Drawing State
    
    /// Multi-line formatted text containing OHLC data and trend information
    private var label: String = ""
    
    /// Calculated size of the tooltip including all content and padding
    private var labelSize: CGSize = .zero
    
    /// Text formatting configuration (left-aligned for OHLC data readability)
    private var paragraphStyle: NSMutableParagraphStyle?
    
    /// Cached text rendering attributes for drawing performance
    private var drawAttributes: [NSAttributedString.Key : Any] = [:]
    
    // MARK: - Init
    
    /**
     * Initializes a new CandlestickBalloonMarker with customizable appearance
     * 
     * - Parameters:
     *   - color: Background color for the tooltip
     *   - font: Font for the OHLC data text
     *   - textColor: Color of the text content
     *   - insets: Padding around the tooltip content (top, left, bottom, right)
     */
    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        super.init()
        
        // Configure text alignment for OHLC data display
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle?.alignment = .left  // Left-align for better readability of multiple data lines
    }
    
    // MARK: - Date Management
    
    /**
     * Updates the date mapping array used to convert X-axis indices to actual dates
     * 
     * Candlestick charts use integer indices for X values instead of timestamps,
     * so this mapping is essential for displaying correct dates in tooltips.
     * 
     * - Parameter dates: Array of Date objects corresponding to each candlestick data point
     */
    func updateDates(_ dates: [Date]) {
        self.dateMap = dates
    }
    
    /**
     * Updates the current time range filter to adjust date/time formatting in tooltips
     * - Parameter range: Time range string ("24h", "7d", "30d", "All")
     */
    func updateRange(_ range: String) {
        self.currentRange = range
    }
    
    // MARK: - Update Content
    
    /**
     * Called by DGCharts when a candlestick is highlighted to refresh tooltip content
     * 
     * This method creates a comprehensive OHLC tooltip containing:
     * 1. Date/time formatted based on current range
     * 2. Open, High, Low, Close prices
     * 3. Price change and percentage change
     * 4. Trend indicator (📈 for bullish, 📉 for bearish)
     * 
     * - Parameters:
     *   - entry: The selected candlestick data point (CandleChartDataEntry)
     *   - highlight: Highlight information (position, dataset index, etc.)
     */
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Convert X-axis index to actual date using the date mapping
        // (Candlestick charts use integer indices instead of timestamps for performance)
        let index = Int(entry.x)
        let date: Date
        
        if index >= 0 && index < dateMap.count {
            date = dateMap[index]
        } else {
            // Safety fallback if index is somehow out of bounds
            date = Date()
        }
        
        let formatter = DateFormatter()
        // Ensure tooltip shows local timezone (Singapore time for this user)
        formatter.timeZone = TimeZone.current
        // Adaptive date formatting optimized for different trading timeframes
        if currentRange == "24h" {
            // For intraday trading, show precise time with AM/PM
            formatter.dateFormat = "h:mm a"  // "9:30 AM", "12:45 PM"
        } else {
            // For longer periods, show date + time for context
            formatter.dateFormat = "MM/dd HH:mm"  // "07/22 14:30"
        }
        
        // Extract OHLC data and create comprehensive tooltip content
        if let candleEntry = entry as? CandleChartDataEntry {
            // Analyze candlestick sentiment (bullish vs bearish)
            let isBullish = candleEntry.close >= candleEntry.open
            let trendIcon = isBullish ? "📈" : "📉"
            
            // Calculate price change metrics for trader insight
            let changeValue = candleEntry.close - candleEntry.open
            let changePercent = (changeValue / candleEntry.open) * 100
            
            // Build professional multi-line OHLC tooltip with all essential trading data
            label = """
            \(trendIcon) \(formatter.string(from: date))
            Open: $\(String(format: "%.2f", candleEntry.open))
            High: $\(String(format: "%.2f", candleEntry.high))
            Low:  $\(String(format: "%.2f", candleEntry.low))
            Close: $\(String(format: "%.2f", candleEntry.close))
            Change: \(changeValue >= 0 ? "+" : "")\(String(format: "%.2f", changePercent))%
            """
        } else {
            // Safety fallback for non-candlestick entries (shouldn't happen in normal usage)
            label = "\(formatter.string(from: date))\n$\(String(format: "%.2f", entry.y))"
        }
        
        // Configure text rendering attributes for consistent tooltip appearance
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: textColor
        ]
        
        // Calculate total tooltip dimensions including padding for proper positioning
        let size = label.size(withAttributes: attributes)
        labelSize = CGSize(width: size.width + insets.left + insets.right,
                          height: size.height + insets.top + insets.bottom)
        
        // Cache attributes for efficient drawing performance
        drawAttributes = attributes
    }
    
    // MARK: - Positioning
    
    /**
     * Calculates the optimal position for the candlestick tooltip relative to the tapped point
     * 
     * Positioning strategy:
     * - Centers the tooltip horizontally above the selected candlestick
     * - Maintains consistent padding from the candle top
     * - Applies minimum size constraints if configured
     * 
     * This simpler approach prioritizes consistency over complex edge detection,
     * providing predictable tooltip placement for candlestick analysis.
     * 
     * - Parameter point: The chart coordinate where the user tapped (center of candlestick)
     * - Returns: Offset vector for positioning the tooltip's top-left corner
     */
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        var offset = self.offset
        var size = labelSize
        
        // Apply minimum size constraints if configured
        if customMinimumSize.width > 0.0 && customMinimumSize.height > 0.0 {
            size.width = max(size.width, customMinimumSize.width)
            size.height = max(size.height, customMinimumSize.height)
        }
        
        let width = size.width
        let height = size.height
        let padding: CGFloat = 8.0  // Gap between candlestick and tooltip
        
        // Center tooltip horizontally above the candlestick with consistent spacing
        offset.x = -width / 2.0
        offset.y = -height - padding
        
        return offset
    }
    
    // MARK: - Drawing
    
    /**
     * Renders the professional-styled candlestick tooltip on the chart canvas
     * 
     * Drawing layers (bottom to top):
     * 1. Drop shadow for depth perception
     * 2. Rounded background with custom color
     * 3. Subtle border for definition
     * 4. Connection line to the referenced candlestick
     * 5. Multi-line OHLC text content
     * 
     * This creates a polished, professional appearance suitable for trading applications.
     * 
     * - Parameters:
     *   - context: Core Graphics context for rendering
     *   - point: Original chart coordinate of the selected candlestick
     */
    override func draw(context: CGContext, point: CGPoint) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        
        var size = labelSize
        
        // Apply minimum size constraints for consistent tooltip dimensions
        if customMinimumSize.width > 0.0 && customMinimumSize.height > 0.0 {
            size.width = max(size.width, customMinimumSize.width)
            size.height = max(size.height, customMinimumSize.height)
        }
        
        // Calculate final tooltip rectangle position
        let rect = CGRect(origin: CGPoint(x: point.x + offset.x, y: point.y + offset.y), size: size)
        
        // Layer 1: Add subtle drop shadow for depth and better readability
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.1).cgColor)
        
        // Layer 2: Draw rounded background for modern appearance
        context.setFillColor(color.cgColor)
        let cornerRadius: CGFloat = 12.0
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Clear shadow before drawing border and text
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // Layer 3: Add subtle border for definition against chart background
        context.setStrokeColor(UIColor.separator.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.addPath(path.cgPath)
        context.strokePath()
        
        // Layer 4: Draw connection line to clearly indicate which candle is selected
        drawConnectionLine(context: context, from: point, to: rect)
        
        // Layer 5: Render the formatted OHLC text content
        if !label.isEmpty {
            let textRect = rect.insetBy(dx: insets.left, dy: insets.top)
            label.draw(in: textRect, withAttributes: drawAttributes)
        }
    }
    
    /**
     * Draws a visual connection line between the selected candlestick and its tooltip
     * 
     * This helper method:
     * 1. Calculates if a connection line is needed (based on distance)
     * 2. Finds the optimal connection point on the tooltip edge
     * 3. Draws a subtle dotted line for clear visual association
     * 
     * The connection line helps users understand which specific candlestick the
     * tooltip is referencing, especially when multiple candles are close together.
     * 
     * - Parameters:
     *   - context: Core Graphics context for drawing
     *   - point: Original position of the selected candlestick
     *   - rect: Final positioned rectangle of the tooltip
     */
    private func drawConnectionLine(context: CGContext, from point: CGPoint, to rect: CGRect) {
        // Calculate distance to determine if connection line is beneficial
        let tooltipCenter = CGPoint(x: rect.midX, y: rect.midY)
        let distance = sqrt(pow(tooltipCenter.x - point.x, 2) + pow(tooltipCenter.y - point.y, 2))
        
        // Only draw connection line if tooltip is significantly offset (avoids visual clutter)
        guard distance > 30 else { return }
        
        // Find the optimal connection point on the tooltip's edge closest to the candlestick
        let connectionPoint: CGPoint
        
        if point.y < rect.minY {
            // Candlestick is above tooltip - connect to top edge with horizontal centering
            connectionPoint = CGPoint(x: max(rect.minX + 10, min(rect.maxX - 10, point.x)), y: rect.minY)
        } else if point.y > rect.maxY {
            // Candlestick is below tooltip - connect to bottom edge with horizontal centering
            connectionPoint = CGPoint(x: max(rect.minX + 10, min(rect.maxX - 10, point.x)), y: rect.maxY)
        } else {
            // Candlestick is at tooltip level - connect to nearest vertical edge
            if point.x < rect.minX {
                connectionPoint = CGPoint(x: rect.minX, y: point.y)
            } else {
                connectionPoint = CGPoint(x: rect.maxX, y: point.y)
            }
        }
        
        // Draw subtle dotted line for clear but non-intrusive connection
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [3, 3])  // 3pt dashes with 3pt gaps
        
        context.move(to: point)
        context.addLine(to: connectionPoint)
        context.strokePath()
        
        // Reset line dash state for subsequent drawing operations
        context.setLineDash(phase: 0, lengths: [])
    }
    
    /**
     * Sets a minimum size constraint for the tooltip to ensure consistent dimensions
     * 
     * This is useful when you want all tooltips to have a uniform minimum size
     * regardless of content length, creating a more polished and consistent UI.
     * 
     * - Parameter size: Minimum width and height for the tooltip (CGSize.zero to disable)
     */
    func setMinimumSize(_ size: CGSize) {
        customMinimumSize = size
    }
} 