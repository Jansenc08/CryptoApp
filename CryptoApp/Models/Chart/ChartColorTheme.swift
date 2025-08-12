import UIKit

// MARK: - Chart Color Theme Enum

enum ChartColorTheme: String, CaseIterable {
    case classic = "classic"
    case ocean = "ocean"
    case monochrome = "monochrome"
    case accessibility = "accessibility"
    
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .ocean: return "Ocean"
        case .monochrome: return "Monochrome"
        case .accessibility: return "Accessibility"
        }
    }
    
    var positiveColor: UIColor {
        switch self {
        case .classic: return .systemGreen
        case .ocean: return .systemBlue
        case .monochrome: return .systemGray
        case .accessibility: return UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0) // High contrast green
        }
    }
    
    var negativeColor: UIColor {
        switch self {
        case .classic: return .systemRed
        case .ocean: return .systemOrange
        case .monochrome: return .systemGray2
        case .accessibility: return UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0) // High contrast red
        }
    }
} 