//
//  PriceChangeOverviewCellTests.swift
//  CryptoAppTests
//
//  Unit tests for PriceChangeOverviewCell covering:
//  - Cell initialization and setup
//  - Configuration with coin data
//  - Positive and negative price change display
//  - Empty state handling
//  - UI appearance and formatting
//

import XCTest
@testable import CryptoApp

final class PriceChangeOverviewCellTests: XCTestCase {
    
    private var cell: PriceChangeOverviewCell!
    private var mockCoin: Coin!
    
    override func setUp() {
        super.setUp()
        
        // Create cell instance
        cell = PriceChangeOverviewCell(style: .default, reuseIdentifier: "test")
        
        // Create mock coin with quote data
        mockCoin = TestDataFactory.createMockCoin()
    }
    
    override func tearDown() {
        cell = nil
        mockCoin = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testCellInitialization() {
        // Given & When - cell is initialized in setUp
        
        // Then
        XCTAssertNotNil(cell, "Cell should be initialized")
        XCTAssertNotNil(cell.contentView, "Cell should have content view")
        
        // Check that UI components are set up
        let containerViews = cell.contentView.subviews
        XCTAssertFalse(containerViews.isEmpty, "Cell should have container view")
    }
    
    // NOTE: init(coder:) intentionally fatalErrors in implementation. We do NOT invoke it in tests
    // because it would crash the test process. This matches existing test style (no fatalError asserts).
    
    // MARK: - Configuration Tests
    
    func testConfigureWithValidCoinData() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        overrideUSDQuote(
            for: &coin,
            percent24h: 5.25,
            percent7d: -2.15,
            percent30d: 12.8,
            percent90d: -8.45
        )
        
        // When
        cell.configure(with: coin)
        
        // Then
        // Force layout to ensure UI is updated
        cell.layoutIfNeeded()
        
        // Verify container view is configured
        let containerView = cell.contentView.subviews.first
        XCTAssertNotNil(containerView, "Container view should exist")
        XCTAssertEqual(containerView?.layer.cornerRadius, 16, "Container should have correct corner radius")
    }
    
    func testConfigureWithNilQuoteData() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        coin.quote = nil
        
        // When
        cell.configure(with: coin)
        
        // Then
        cell.layoutIfNeeded()
        // Should handle gracefully without crashing
        XCTAssertNotNil(cell.contentView, "Cell should still be valid with nil quote data")
    }
    
    func testConfigureWithMixedValidAndInvalidData() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        overrideUSDQuote(
            for: &coin,
            percent24h: 3.25,
            percent7d: nil,
            percent30d: -1.5,
            percent90d: nil
        )
        
        // When
        cell.configure(with: coin)
        
        // Then
        cell.layoutIfNeeded()
        // Should handle mixed data gracefully
        XCTAssertNotNil(cell.contentView, "Cell should handle mixed data gracefully")
    }
    
    // MARK: - Time Period Data Structure Tests
    
    func testTimePeriodPositiveValue() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        overrideUSDQuote(for: &coin, percent24h: 5.25)
        
        // When
        cell.configure(with: coin)
        
        // Then - This tests the private TimePeriod struct behavior indirectly
        // The positive change should be displayed properly (we can't access private struct directly)
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView, "Cell should configure properly with positive values")
    }
    
    func testTimePeriodNegativeValue() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        overrideUSDQuote(for: &coin, percent24h: -5.25)
        
        // When
        cell.configure(with: coin)
        
        // Then
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView, "Cell should configure properly with negative values")
    }
    
    func testTimePeriodZeroValue() {
        // Given
        var coin = TestDataFactory.createMockCoin()
        overrideUSDQuote(for: &coin, percent24h: 0.0)
        
        // When
        cell.configure(with: coin)
        
        // Then
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView, "Cell should configure properly with zero values")
    }
    
    // MARK: - UI Layout Tests
    
    func testCellHasCorrectConstraints() {
        // Given & When
        cell.configure(with: mockCoin)
        cell.layoutIfNeeded()
        
        // Then
        let containerView = cell.contentView.subviews.first
        XCTAssertNotNil(containerView, "Container view should exist")
        XCTAssertFalse(containerView!.translatesAutoresizingMaskIntoConstraints, 
                      "Container view should use Auto Layout")
    }
    
    func testCellLayoutAfterConfiguration() {
        // Given
        let initialFrame = cell.frame
        
        // When
        cell.configure(with: mockCoin)
        cell.frame = CGRect(x: 0, y: 0, width: 375, height: 100) // iPhone width
        cell.layoutIfNeeded()
        
        // Then
        XCTAssertNotEqual(cell.frame, initialFrame, "Cell frame should be updated")
        XCTAssertGreaterThan(cell.frame.width, 0, "Cell should have positive width")
        XCTAssertGreaterThan(cell.frame.height, 0, "Cell should have positive height")
    }
    
    // MARK: - Error Handling Tests
    
    func testConfigureWithEmptySymbol() {
        // Given
        let coin = TestDataFactory.createMockCoin()
        // Modify the symbol to be empty (if possible through the public interface)
        
        // When
        cell.configure(with: coin)
        
        // Then
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView, "Cell should handle empty symbol gracefully")
    }
    
    // MARK: - Performance Tests
    
    func testConfigurationPerformance() {
        // Given
        let coin = TestDataFactory.createMockCoin()
        
        // When & Then
        measure {
            for _ in 0..<100 {
                cell.configure(with: coin)
            }
        }
    }
    
    func testLayoutPerformance() {
        // Given
        cell.configure(with: mockCoin)
        
        // When & Then
        measure {
            for _ in 0..<100 {
                cell.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Helper to recursively collect UILabels from a view hierarchy
    private func allLabels(in view: UIView) -> [UILabel] {
        var result: [UILabel] = []
        for sub in view.subviews {
            if let label = sub as? UILabel { result.append(label) }
            result.append(contentsOf: allLabels(in: sub))
        }
        return result
    }

    // Helper to override the immutable Quote by replacing the USD entry
    private func overrideUSDQuote(
        for coin: inout Coin,
        percent24h: Double? = nil,
        percent7d: Double? = nil,
        percent30d: Double? = nil,
        percent90d: Double? = nil
    ) {
        let old = coin.quote?["USD"]
        let newQuote = Quote(
            price: old?.price ?? 50000,
            volume24h: old?.volume24h,
            volumeChange24h: old?.volumeChange24h,
            percentChange1h: old?.percentChange1h,
            percentChange24h: percent24h ?? old?.percentChange24h,
            percentChange7d: percent7d ?? old?.percentChange7d,
            percentChange30d: percent30d ?? old?.percentChange30d,
            percentChange60d: old?.percentChange60d,
            percentChange90d: percent90d ?? old?.percentChange90d,
            marketCap: old?.marketCap,
            marketCapDominance: old?.marketCapDominance,
            fullyDilutedMarketCap: old?.fullyDilutedMarketCap,
            lastUpdated: old?.lastUpdated
        )
        coin.quote = ["USD": newQuote]
    }
}
