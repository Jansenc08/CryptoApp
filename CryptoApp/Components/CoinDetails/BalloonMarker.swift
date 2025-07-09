import DGCharts
import UIKit

class BalloonMarker: MarkerImage {

    // MARK: - Configuration Properties

    private var color: UIColor
    private var font: UIFont
    private var textColor: UIColor
    private var insets: UIEdgeInsets //  Padding inside tooltip
    private var customMinimumSize = CGSize()
    
    // MARK: - Internal Drawing State

    private var label: String = ""
    private var labelSize: CGSize = .zero
    private var paragraphStyle: NSMutableParagraphStyle?
    private var drawAttributes: [NSAttributedString.Key : Any] = [:]

    // MARK: - Init

    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        super.init()
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle?.alignment = .center //  Center align text
    }
    
    // MARK: - Update Content

    // Called whenever a new chart entry is highlighted.
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let date = Date(timeIntervalSince1970: entry.x)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"

        // Build label with date + price
        label = "\(formatter.string(from: date))\n$\(String(format: "%.2f", entry.y))"

        // Text drawing attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: textColor
        ]

        // Calculate size based on text and insets
        let size = label.size(withAttributes: attributes)
        labelSize = CGSize(width: size.width + insets.left + insets.right,
                           height: size.height + insets.top + insets.bottom)
        drawAttributes = attributes
    }

    // MARK: - Positioning
    
    // Calculates where the marker should appear on screen.
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        var x = point.x - labelSize.width / 2
        var y = point.y - labelSize.height - 8

        if x < 0 { x = 0 }
        if y < 0 { y = 0 }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing

    // Draw the label balloon at the calculated point.
    override func draw(context: CGContext, point: CGPoint) {
        guard !label.isEmpty else { return }

        let offset = offsetForDrawing(atPoint: point)
        let rect = CGRect(origin: offset, size: labelSize)

        // Draw background rectangle
        context.setFillColor(color.cgColor)
        context.fill(rect)

        // Draw the label string inside the rect
        label.draw(in: rect.inset(by: insets), withAttributes: drawAttributes)
    }

    func setMinimumSize(_ size: CGSize) {
        self.customMinimumSize = size
    }
}
