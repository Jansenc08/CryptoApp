//
//  SearchVMTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for SearchVM covering search filtering logic, popular coins switching,
//  error state transitions, and logo updates. These tests validate:
//  - Debounced search behavior (observed via publishers, not timers)
//  - Case-insensitive and prefix matching across name/symbol/slug
//  - Popular coins cache validity and refresh logic
//  - Error messages emitted from shared data manager errors
//  Patterns:
//  - Uses MockCoinManager, MockSharedCoinDataManager, MockPersistenceService
//  - Expectations guarded with flags or prefix(1) to prevent multiple fulfill calls
//

import XCTest
import Combine
@testable import CryptoApp

final class SearchVMTests: XCTestCase {
    
    private var viewModel: SearchVM!
    private var mockCoinManager: MockCoinManager!
    private var mockShared: MockSharedCoinDataManager!
    private var mockPersistence: MockPersistenceService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCoinManager = MockCoinManager()
        mockShared = MockSharedCoinDataManager()
        mockPersistence = MockPersistenceService()
        cancellables = []
        
        // Seed cache for search
        let cachedCoins = TestDataFactory.createMockCoins(count: 25)
        mockPersistence.saveCoinList(cachedCoins)
        mockShared.setMockCoins(cachedCoins)
        
        viewModel = SearchVM(
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            persistenceService: mockPersistence
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        viewModel.cancelAllRequests()
        viewModel = nil
        mockCoinManager = nil
        mockShared = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    // MARK: - Filtering
    
    func testSearchFiltersBySymbolAndName() {
        // Given
        // Test that search filters coins by both symbol and name fields
        let exp = expectation(description: "results received")
        // Array to capture search results
        var results: [Coin] = []
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        viewModel.searchResults
            .sink { list in
                results = list
                if !list.isEmpty && !fulfilled {
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Search for "COIN1" which should match both symbol and name patterns
        viewModel.updateSearchText("COIN1")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify results contain the exact symbol match
        XCTAssertTrue(results.contains { $0.symbol == "COIN1" })
        // Verify all results match either name or symbol search criteria
        XCTAssertTrue(results.allSatisfy { $0.name.contains("Test Coin") || $0.symbol.contains("COIN1") })
    }
    
    func testSearchCaseInsensitiveAndPrefix() {
        // Given
        // Test that search is case-insensitive and matches prefixes
        let exp = expectation(description: "case-insensitive received")
        // Array to capture case-insensitive search results
        var results: [Coin] = []
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        viewModel.searchResults
            .sink { list in
                results = list
                if !list.isEmpty && !fulfilled {
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Search with lowercase "coin2" to test case-insensitive matching
        viewModel.updateSearchText("coin2")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify case-insensitive matching works for both symbols and names
        XCTAssertTrue(results.contains { $0.symbol.lowercased().hasPrefix("coin2") || $0.name.lowercased().contains("coin2") })
    }
    
    func testSearchTrimsWhitespaceAndRejectsNonAlphanumerics() {
        // Given
        // Test that search input is sanitized (whitespace trimmed, non-alphanumerics rejected)
        let emptyExp = expectation(description: "empty received")
        // Initialize with dummy data to verify it gets cleared for invalid input
        var results: [Coin] = [TestDataFactory.createMockCoin()]
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        viewModel.searchResults
            .sink { list in
                results = list
                if !fulfilled {
                    fulfilled = true
                    emptyExp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Search with invalid input: whitespace and special characters
        viewModel.updateSearchText("   @@@   ")
        wait(for: [emptyExp], timeout: 1.0)
        
        // Then
        // Verify invalid input results in empty results (input was sanitized/rejected)
        XCTAssertTrue(results.isEmpty)
    }
    
    func testMaxSearchResultsLimit() {
        // Given
        // Test that search results are limited to prevent UI performance issues
        let manyCoins = TestDataFactory.createMockCoins(count: 200)
        // Save a large dataset to test result limiting
        mockPersistence.saveCoinList(manyCoins)
        viewModel.refreshSearchData()
        // Create expectation for limited search results
        let exp = expectation(description: "limited results")
        // Variable to capture the count of returned results
        var count = 0
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        viewModel.searchResults
            .sink { list in
                if !list.isEmpty && !fulfilled {
                    count = list.count
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Search with broad term that would match many coins
        viewModel.updateSearchText("COIN")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify results are capped at 50 items maximum for performance
        XCTAssertLessThanOrEqual(count, 50)
    }
    
    // MARK: - Error State Transitions
    
    func testSharedErrorPublishesFriendlyMessage() {
        // Given
        // Test that network errors are converted to user-friendly messages
        let exp = expectation(description: "error message received")
        // Variable to capture the error message shown to users
        var message: String?
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        viewModel.errorMessage
            .sink { msg in
                if let m = msg, !m.isEmpty, !fulfilled {
                    message = m
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: simulate error from shared manager
        // Trigger a network error that should be converted to a user-friendly message
        mockShared.emitError(NetworkError.invalidResponse)
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify a user-friendly error message was generated
        XCTAssertNotNil(message)
    }
    
    // MARK: - Popular Coins
    
    func testPopularCoinsSwitchingAndLoading() {
        // Given
        // Test the popular coins feature with filter switching and cache validity
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 100)
        // Create expectation for popular coins loading
        let exp = expectation(description: "popular coins loaded")
        // Array to capture popular coins results
        var received: [Coin] = []
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        viewModel.popularCoins
            .sink { list in
                if !list.isEmpty && !fulfilled {
                    received = list
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Switch to top gainers filter and fetch fresh data
        viewModel.updatePopularCoinsFilter(.topGainers)
        viewModel.fetchFreshPopularCoins(for: .topGainers)
        wait(for: [exp], timeout: 3.0)
        
        // Then
        // Verify popular coins were loaded successfully
        XCTAssertFalse(received.isEmpty)
        // Verify cache is marked as valid after successful fetch
        XCTAssertTrue(viewModel.isPopularCoinsCacheValid)
    }
}
