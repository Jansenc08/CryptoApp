import DGCharts
import UIKit

class BalloonMarker: MarkerImage {

    private var color: UIColor
    private var font: UIFont
    private var textColor: UIColor
    private var insets: UIEdgeInsets
    private var customMinimumSize = CGSize() // renamed to avoid conflict

    private var label: String = ""
    private var labelSize: CGSize = .zero
    private var paragraphStyle: NSMutableParagraphStyle?
    private var drawAttributes: [NSAttributedString.Key : Any] = [:]

    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        super.init()
        paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle?.alignment = .center
    }

    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let date = Date(timeIntervalSince1970: entry.x)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"

        label = "\(formatter.string(from: date))\n$\(String(format: "%.2f", entry.y))"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: textColor
        ]

        let size = label.size(withAttributes: attributes)
        labelSize = CGSize(width: size.width + insets.left + insets.right,
                           height: size.height + insets.top + insets.bottom)
        drawAttributes = attributes
    }

    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        var x = point.x - labelSize.width / 2
        var y = point.y - labelSize.height - 8

        if x < 0 { x = 0 }
        if y < 0 { y = 0 }

        return CGPoint(x: x, y: y)
    }

    override func draw(context: CGContext, point: CGPoint) {
        guard !label.isEmpty else { return }

        let offset = offsetForDrawing(atPoint: point)
        let rect = CGRect(origin: offset, size: labelSize)

        context.setFillColor(color.cgColor)
        context.fill(rect)

        label.draw(in: rect.inset(by: insets), withAttributes: drawAttributes)
    }

    func setMinimumSize(_ size: CGSize) {
        self.customMinimumSize = size
    }
}
