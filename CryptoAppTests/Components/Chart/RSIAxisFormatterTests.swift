//
//  RSIAxisFormatterTests.swift
//  CryptoAppTests
//

import XCTest
import DGCharts
@testable import CryptoApp

final class RSIAxisFormatterTests: XCTestCase {

    func testReturnsEmptyStringInsideRSISection() {
        // Given: RSI section between 0..100, price starts at 200
        let formatter = RSISeparateAxisFormatter(rsiStart: 0, rsiEnd: 100, priceStart: 200)
        // When: value within RSI bounds
        let label = formatter.stringForValue(50, axis: nil)
        // Then: hidden
        XCTAssertEqual(label, "")
    }

    func testReturnsEmptyStringInGapBetweenSections() {
        // Given: gap 101..199
        let formatter = RSISeparateAxisFormatter(rsiStart: 0, rsiEnd: 100, priceStart: 200)
        // When
        let label = formatter.stringForValue(150, axis: nil)
        // Then: hidden
        XCTAssertEqual(label, "")
    }

    func testPriceSectionUsesPriceFormatterAbbreviations() {
        // Given: price section starts at 200
        let formatter = RSISeparateAxisFormatter(rsiStart: 0, rsiEnd: 100, priceStart: 200)
        // When: large values format via PriceFormatter
        let kLabel = formatter.stringForValue(2_500, axis: nil)
        let mLabel = formatter.stringForValue(3_000_000, axis: nil)
        let dollars = formatter.stringForValue(250, axis: nil)
        // Then
        XCTAssertEqual(kLabel, "$2.5K")
        XCTAssertEqual(mLabel, "$3.0M")
        XCTAssertEqual(dollars, "$250")
    }

    func testMicroPricesFormatInPriceSection() {
        let formatter = RSISeparateAxisFormatter(rsiStart: 0, rsiEnd: 100, priceStart: 200)
        // When: micro values
        let micro = formatter.stringForValue(200.00045, axis: nil)
        // Then: PriceFormatter should still show as integer dollars for >= 1
        XCTAssertEqual(micro, "$200")
    }
}


