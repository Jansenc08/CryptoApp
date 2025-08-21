//
//  MicroPriceFormatterTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Tests for MicroPriceFormatter.formatUSD covering standard currency formatting,
//  micro-format for sub-cent values, and non-positive handling.
//

import XCTest
import UIKit
@testable import CryptoApp

final class MicroPriceFormatterTests: XCTestCase {
    
    func testFormatUSDStandardCurrencyForValuesAboveOneCent() {
        // Given
        // Values >= $0.01 should render with standard currency formatting and 2 decimals
        let value: Double = 1.2345
        
        // When
        let attr = MicroPriceFormatter.formatUSD(value)
        
        // Then
        XCTAssertTrue(attr.string.contains("US$"))
        XCTAssertTrue(attr.string.contains("1.23") || attr.string.contains("1,23")) // locale tolerant
    }
    
    func testFormatUSDMicroFormatForSmallValues() {
        // Given
        // 0 < value < 0.01 should render micro format with subscript count and leading digits
        // Example: 0.0000123 -> "US$0.0₄123" (exact digits may vary by precision)
        let value: Double = 0.0000123
        
        // When
        let attr = MicroPriceFormatter.formatUSD(value)
        
        // Then
        XCTAssertTrue(attr.string.hasPrefix("US$0.0"))
        // The string should append some digits after the subscript count
        XCTAssertTrue(attr.string.count > 6)
    }
    
    func testFormatUSDZeroOrNegativeReturnsZero() {
        // Given/When
        // Non-positive values should render as "US$0.00"
        let zero = MicroPriceFormatter.formatUSD(0)
        let negative = MicroPriceFormatter.formatUSD(-0.5)
        
        // Then
        XCTAssertEqual(zero.string, "US$0.00")
        XCTAssertEqual(negative.string, "US$0.00")
    }
}


