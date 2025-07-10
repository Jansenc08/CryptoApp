//
//  Double+Abbreviation.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

// Formats Large numbers into short, readable strings
// eg: 1234.0 -> 1.23K
// 5600000.0 -> 5.60M
extension Double {
    func formattedWithAbbreviations() -> String {
        let num = abs(self)
        let sign = self < 0 ? "-" : ""
        
        switch num {
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000))M"
        case 1_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000))K"
        default:
            return "\(sign)\(String(format: "%.2f", self))"
        }
    }
}
