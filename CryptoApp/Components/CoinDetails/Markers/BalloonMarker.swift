import DGCharts
import UIKit

/**
 * BalloonMarker creates a tooltip popup for line charts that displays price and time information
 * when users tap on data points.
 * 
 * Features:
 * - Adaptive time formatting based on chart time range (24h shows time, others show date+time)
 * - Automatic positioning to stay within chart bounds
 * - Customizable appearance (colors, fonts, padding)
 * - Smooth integration with DGCharts highlighting system
 */
class BalloonMarker: MarkerImage {

    // MARK: - Configuration Properties

    /// Background color of the tooltip balloon
    private var color: UIColor
    
    /// Font used for the tooltip text
    private var font: UIFont
    
    /// Text color inside the tooltip
    private var textColor: UIColor
    
    /// Padding around the text inside the tooltip balloon
    private var insets: UIEdgeInsets
    
    /// Minimum size constraint for the tooltip (if needed)
    private var customMinimumSize = CGSize()
    
    /// Current time range filter that affects date/time formatting
    private var currentRange: String = "24h"
    
    // MARK: - Internal Drawing State

    /// The formatted text to display in the tooltip
    private var label: String = ""
    
    /// Calculated size of the tooltip including text and padding
    private var labelSize: CGSize = .zero
    
    /// Text alignment and formatting configuration
    private var paragraphStyle: NSMutableParagraphStyle?
    
    /// Cached text rendering attributes for performance
    private var drawAttributes: [NSAttributedString.Key : Any] = [:]

    // MARK: - Init

    /**
     * Initializes a new BalloonMarker with customizable appearance
     * 
     * - Parameters:
     *   - color: Background color of the tooltip balloon
     *   - font: Font for the tooltip text
     *   - textColor: Color of the text inside the tooltip
     *   - insets: Padding around the text (top, left, bottom, right)
     */
    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        super.init()
        
        // Configure text alignment for centered tooltip content
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle?.alignment = .center
    }
    
    // MARK: - Range Management
    
    /**
     * Updates the current time range filter to adjust date/time formatting
     * - Parameter range: Time range string ("24h", "7d", "30d", "All")
     */
    func updateRange(_ range: String) {
        self.currentRange = range
    }
    
    // MARK: - Update Content

    /**
     * Called by DGCharts when a data point is highlighted to refresh tooltip content
     * 
     * This method:
     * 1. Extracts the timestamp and price from the chart entry
     * 2. Formats the date/time based on current range (24h = time only, others = date+time)
     * 3. Creates a formatted label with price information
     * 4. Calculates the tooltip size including padding
     * 
     * - Parameters:
     *   - entry: The selected chart data point containing x (timestamp) and y (price)
     *   - highlight: Highlight information (position, dataset index, etc.)
     */
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Convert the chart's x-value (Unix timestamp) to a readable date
        let date = Date(timeIntervalSince1970: entry.x)
        let formatter = DateFormatter()
        // Ensure tooltip shows local timezone (Singapore time for this user)
        formatter.timeZone = TimeZone.current
        
        // Adaptive date formatting based on time range for optimal UX
        if currentRange == "24h" {
            // For intraday trading, show precise time
            formatter.dateFormat = "h:mm a"  // "9:30 AM"
        } else {
            // For longer periods, show date + time for context
            formatter.dateFormat = "dd MMM HH:mm"  // "22 Jul 14:30"
        }

        // Create a two-line tooltip: date/time on top, price below
        let priceString: String
        if entry.y >= 1 {
            priceString = String(format: "$%.2f", entry.y)
        } else if entry.y > 0 {
            // Choose decimals dynamically so first non-zero is visible (max 10)
            var decimals = 6
            var v = entry.y
            while v < 1 && v > 0 && decimals < 10 {
                v *= 10
                if v >= 1 { break }
                decimals += 1
            }
            let clamped = max(4, min(decimals, 10))
            priceString = String(format: "$%.*f", clamped, entry.y)
        } else {
            priceString = "$0"
        }
        label = "\(formatter.string(from: date))\n\(priceString)"

        // Configure text rendering attributes for consistent appearance
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: textColor
        ]

        // Calculate total tooltip size including padding for proper positioning
        let size = label.size(withAttributes: attributes)
        labelSize = CGSize(width: size.width + insets.left + insets.right,
                           height: size.height + insets.top + insets.bottom)
        
        // Cache attributes for drawing performance
        drawAttributes = attributes
    }

    // MARK: - Positioning
    
    /**
     * Calculates the optimal position for the tooltip to avoid going off-screen
     * 
     * Positioning strategy:
     * 1. Center the tooltip horizontally above the tapped point
     * 2. Place it above the point with a small gap (8pt)
     * 3. Apply boundary checks to keep it within screen bounds
     * 
     * - Parameter point: The chart point where the user tapped (in chart coordinates)
     * - Returns: Adjusted position for the top-left corner of the tooltip
     */
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // Center the tooltip horizontally on the tapped point
        var x = point.x - labelSize.width / 2
        
        // Position tooltip above the point with a small gap
        var y = point.y - labelSize.height - 8

        // Boundary checking to prevent tooltip from going off-screen
        if x < 0 { x = 0 }  // Don't go off left edge
        if y < 0 { y = 0 }  // Don't go off top edge
        
        // Note: Right and bottom edge checking could be added if needed
        // by checking against chartView bounds in the containing view

        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing

    /**
     * Renders the tooltip balloon on the chart canvas
     * 
     * Drawing process:
     * 1. Calculate final position using offsetForDrawing
     * 2. Draw the background rectangle with the specified color
     * 3. Draw the text inside the rectangle with proper padding
     * 
     * - Parameters:
     *   - context: Core Graphics context for drawing
     *   - point: The original chart point (before offset calculation)
     */
    override func draw(context: CGContext, point: CGPoint) {
        // Safety check to avoid drawing empty tooltips
        guard !label.isEmpty else { return }

        // Get the final adjusted position for the tooltip
        let offset = offsetForDrawing(atPoint: point)
        let rect = CGRect(origin: offset, size: labelSize)

        // Draw the background balloon shape
        context.setFillColor(color.cgColor)
        context.fill(rect)

        // Draw the formatted text inside the balloon with proper padding
        label.draw(in: rect.inset(by: insets), withAttributes: drawAttributes)
    }

    /**
     * Sets a minimum size constraint for the tooltip (optional feature)
     * - Parameter size: Minimum width and height for the tooltip
     */
    func setMinimumSize(_ size: CGSize) {
        self.customMinimumSize = size
    }
}
