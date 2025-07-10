//
//  Double+Abbreviation.swift
//  CryptoApp
//
//  Created by Jansen Castillo on 10/7/25.
//

// Converts large numbers into abbreviated strings (e.g., 1.23K, 5.6M, 2.1B, 1.1T)
// eg: 1234.0 -> 1.23K
// 5600000.0 -> 5.60M
extension Double {
    
    func abbreviatedString() -> String {
        let num = abs(self)
        let sign = self < 0 ? "-" : ""

        switch num {
        case 1_000_000_000_000...:
            return "\(sign)\(String(format: "%.2f", num / 1_000_000_000_000))T"
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
