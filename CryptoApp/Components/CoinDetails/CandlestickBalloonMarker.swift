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
    
    /// Attributed string with color-coded changes for better visual feedback
    private var attributedLabel: NSAttributedString?
    
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
    
    // MARK: - Price Formatting
    
    /**
     * Formats price values to match your chart's format (e.g., 117,128.00)
     * Uses number formatter with commas and 2 decimal places
     */
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        return formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
    }
    
    /**
     * Creates color-coded attributed string with green/red for positive/negative values only
     */
    private func createColorCodedTooltip(label: String, changeValue: Double) -> NSAttributedString {
        let lines = label.components(separatedBy: "\n")
        let attributedString = NSMutableAttributedString()
        
        // Create tab stops for proper alignment with more spacing between titles and values
        let tabStop = NSTextTab(textAlignment: .right, location: 110.0) // Increased spacing
        
        // Base styling with tab stops for alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 1.0
        paragraphStyle.tabStops = [tabStop]
        
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: self.textColor
        ]
        
        for (index, line) in lines.enumerated() {
            // Parse each line to separate label and value
            let components = line.components(separatedBy: " ")
            if components.count >= 2 {
                let label = components[0]
                let value = components.dropFirst().joined(separator: " ")
                
                // Create formatted line with tab separation for alignment
                let formattedLine = "\(label)\t\(value)"
                
                // Handle Chg and %Chg lines specially to color only the values
                if label == "Chg" || label == "%Chg" {
                    // Add label part
                    let labelString = NSAttributedString(string: "\(label)\t", attributes: baseAttributes)
                    attributedString.append(labelString)
                    
                    // Add colored value part
                    let valueColor = changeValue >= 0 ? UIColor.systemGreen : UIColor.systemRed
                    var valueAttributes = baseAttributes
                    valueAttributes[.foregroundColor] = valueColor
                    let valueString = NSAttributedString(string: value, attributes: valueAttributes)
                    attributedString.append(valueString)
                } else {
                    // Regular line with tab alignment
                    let attributedLine = NSAttributedString(string: formattedLine, attributes: baseAttributes)
                    attributedString.append(attributedLine)
                }
            } else {
                // Fallback for lines that don't follow the pattern
                let attributedLine = NSAttributedString(string: line, attributes: baseAttributes)
                attributedString.append(attributedLine)
            }
            
            // Add newline except for the last line
            if index < lines.count - 1 {
                attributedString.append(NSAttributedString(string: "\n", attributes: baseAttributes))
            }
        }
        
        return attributedString
    }
    
    // MARK: - Update Content
    
    /**
     * Called by DGCharts when a candlestick is highlighted to refresh tooltip content
     * 
     * Creates an OKX-style tooltip with clean layout and professional formatting:
     * 1. Current price prominently displayed at the top
     * 2. Date/time in header format
     * 3. OHLC data in structured layout
     * 4. Change percentage with color coding
     * 5. Additional metrics (Range, Amount, Turnover) when available
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
        // Always show date and time like OKX
        formatter.dateFormat = "MM/dd HH:mm"  // "08/08 13:05"
        
        // Extract OHLC data and create OKX-style tooltip content
        if let candleEntry = entry as? CandleChartDataEntry {
            // Analyze candlestick sentiment for color coding
            let isBullish = candleEntry.close >= candleEntry.open
            
            // Calculate price change metrics
            let changeValue = candleEntry.close - candleEntry.open
            let changePercent = (changeValue / candleEntry.open) * 100
            let changeSign = changeValue >= 0 ? "+" : "-"
            
            // Calculate additional metrics like OKX
            let range = candleEntry.high - candleEntry.low
            let rangePercent = (range / candleEntry.low) * 100
            
            // Format the current price (close) prominently like OKX
            let formattedPrice = formatPrice(candleEntry.close)
            let formattedChangePercent = String(format: "%.2f", abs(changePercent))
            
            // Build compact tooltip - more vertical and concise
            label = """
            \(formatter.string(from: date))
            Open \(formatPrice(candleEntry.open))
            High \(formatPrice(candleEntry.high))
            Low \(formatPrice(candleEntry.low))
            Close \(formatPrice(candleEntry.close))
            Chg \(changeSign)\(formatPrice(abs(changeValue)))
            %Chg \(changeSign)\(formattedChangePercent)%
            Range \(String(format: "%.2f", rangePercent))%
            """
        } else {
            // Safety fallback for non-candlestick entries
            label = "\(formatPrice(entry.y))\nTime \(formatter.string(from: date))"
        }
        
        // Extract change value for color coding
        let changeValue: Double
        if let candleEntry = entry as? CandleChartDataEntry {
            changeValue = candleEntry.close - candleEntry.open
        } else {
            changeValue = 0
        }
        
        // Create color-coded attributed string for the tooltip
        let colorCodedLabel = createColorCodedTooltip(label: label, changeValue: changeValue)
        
        // Calculate total tooltip dimensions including padding for proper positioning
        let size = colorCodedLabel.size()
        labelSize = CGSize(width: size.width + insets.left + insets.right,
                          height: size.height + insets.top + insets.bottom)
        
        // Store the attributed string for drawing
        self.attributedLabel = colorCodedLabel
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
        
        // Layer 2: Draw adaptive background (dark gray for dark mode, white for light mode)
        context.setFillColor(self.color.cgColor)
        let cornerRadius: CGFloat = 6.0  // More compact radius
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.fillPath()
        
        // Clear shadow before drawing border and text
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // Layer 3: Add adaptive border (light border in dark mode, dark border in light mode)
        let borderColor = self.textColor == UIColor.white ? 
            UIColor.white.withAlphaComponent(0.1) :  // Light border for dark mode
            UIColor.black.withAlphaComponent(0.1)    // Dark border for light mode
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(1.0)
        context.addPath(path.cgPath)
        context.strokePath()
        
        // Layer 4: Render the color-coded OHLC text content (no connection line for cleaner OKX look)
        if let attributedLabel = attributedLabel {
            let textRect = rect.insetBy(dx: insets.left, dy: insets.top)
            attributedLabel.draw(in: textRect)
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
