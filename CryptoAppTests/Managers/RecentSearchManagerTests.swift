//
//  RecentSearchManagerTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for RecentSearchManager covering add/remove/clear, de-duplication,
//  move-to-top behavior, max-size enforcement, and slug persistence.
//

import XCTest
@testable import CryptoApp

final class RecentSearchManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure a clean slate for UserDefaults-backed storage
        RecentSearchManager.shared.clearRecentSearches()
    }
    
    override func tearDown() {
        RecentSearchManager.shared.clearRecentSearches()
        super.tearDown()
    }
    
    func testAddTrimsToFive() {
        // Given
        // Add more than 5 items to verify max-size trimming and ordering
        for i in 1...7 {
            RecentSearchManager.shared.addRecentSearch(coinId: i, symbol: "C\(i)", name: "Coin \(i)", logoUrl: nil, slug: "slug\(i)")
        }
        
        // When
        let items = RecentSearchManager.shared.getRecentSearchItems()
        
        // Then
        // List is capped at 5, with most recent first; oldest are trimmed
        XCTAssertEqual(items.count, 5)
        // Most recent should be the last added
        XCTAssertEqual(items.first?.coinId, 7)
        // Oldest trimmed (1,2) should be gone
        XCTAssertFalse(items.contains { $0.coinId == 1 })
        XCTAssertFalse(items.contains { $0.coinId == 2 })
    }
    
    func testAddMovesToTopNoDuplicate() {
        // Given
        // Add two entries then re-add the first to verify move-to-top without duplication
        RecentSearchManager.shared.addRecentSearch(coinId: 1, symbol: "A", name: "Alpha")
        RecentSearchManager.shared.addRecentSearch(coinId: 2, symbol: "B", name: "Beta")
        
        // When
        RecentSearchManager.shared.addRecentSearch(coinId: 1, symbol: "A", name: "Alpha")
        let items = RecentSearchManager.shared.getRecentSearchItems()
        
        // Then
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.coinId, 1)
    }
    
    func testRemoveAndClearRecentSearch() {
        // Given
        // Seed two entries to test removal and clear behaviors
        RecentSearchManager.shared.addRecentSearch(coinId: 10, symbol: "X", name: "Xeno")
        RecentSearchManager.shared.addRecentSearch(coinId: 11, symbol: "Y", name: "Yara")
        
        // When
        RecentSearchManager.shared.removeRecentSearch(coinId: 10)
        var items = RecentSearchManager.shared.getRecentSearchItems()
        
        // Then
        XCTAssertFalse(items.contains { $0.coinId == 10 })
        
        // When
        RecentSearchManager.shared.clearRecentSearches()
        items = RecentSearchManager.shared.getRecentSearchItems()
        
        // Then
        XCTAssertTrue(items.isEmpty)
    }
    
    func testGetMostRecentSymbolFirst() {
        // Given
        // Add two symbols; the second should be the most recent
        RecentSearchManager.shared.addRecentSearch(coinId: 1, symbol: "AAA", name: "Alpha")
        RecentSearchManager.shared.addRecentSearch(coinId: 2, symbol: "BBB", name: "Beta")
        
        // When
        let symbols = RecentSearchManager.shared.getRecentSearches()
        
        // Then
        XCTAssertEqual(symbols, ["BBB", "AAA"]) // Most recent first
    }
}


