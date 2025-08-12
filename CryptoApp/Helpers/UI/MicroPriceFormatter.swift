import UIKit

/// Utilities to format very small (micro-priced) currency values in the style: $0.0₅123
/// Where the subscript digit (₅) indicates the number of additional zeros between
/// the explicit "0." and the first non-zero significant digits.
/// Example: 0.000000123 -> "$0.0₆123"
enum MicroPriceFormatter {
    /// Builds an attributed string like "$0.0₅187" for values < 0.01.
    /// - Parameters:
    ///   - value: Price value in USD
    ///   - font: Base font used by the label
    /// - Returns: NSAttributedString for display
    static func formatUSD(_ value: Double, font: UIFont = .boldSystemFont(ofSize: 13)) -> NSAttributedString {
        let currency = "US$"
        // Standard formatting for >= 0.01
        if value >= 0.01 {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = "USD"
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            let text = f.string(from: NSNumber(value: value)) ?? "US$0.00"
            return NSAttributedString(string: text, attributes: [.font: font])
        }
        // Guard non-positive
        guard value > 0 else {
            return NSAttributedString(string: currency + "0.00", attributes: [.font: font])
        }

        // Create a high-precision string to inspect leading zeros after decimal
        let raw = String(format: "%.12f", value) // up to 12 fractional digits
        guard let dotIndex = raw.firstIndex(of: ".") else {
            return NSAttributedString(string: currency + raw, attributes: [.font: font])
        }
        let fractional = raw[raw.index(after: dotIndex)...]
        var zeros = 0
        var significant = ""
        for ch in fractional {
            if ch == "0" && significant.isEmpty {
                zeros += 1
                continue
            }
            significant.append(ch)
        }
        // Fallback if we somehow didn't find non-zero digits
        if significant.isEmpty { significant = "0" }
        // Trim trailing zeros in significant portion
        while significant.last == "0" && significant.count > 1 { significant.removeLast() }
        // We print one explicit zero after decimal, the rest as subscript count
        let subCount = max(0, zeros - 1)
        // Keep 3 significant digits for compactness
        let leadingDigits = String(significant.prefix(3))

        // Build attributed string "$0.0₅187"
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: currency + "0.0", attributes: [.font: font]))
        if subCount > 0 {
            let subscriptFont = font.withSize(font.pointSize * 0.85)
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: subscriptFont,
                .baselineOffset: -2 // subscript effect
            ]
            result.append(NSAttributedString(string: "\(subCount)", attributes: subAttr))
        }
        result.append(NSAttributedString(string: leadingDigits, attributes: [.font: font]))
        return result
    }
}


