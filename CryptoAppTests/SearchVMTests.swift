//
//  SearchVMTests.swift
//  CryptoAppTests
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
        let exp = expectation(description: "results received")
        var results: [Coin] = []
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
        viewModel.updateSearchText("COIN1")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertTrue(results.contains { $0.symbol == "COIN1" })
        XCTAssertTrue(results.allSatisfy { $0.name.contains("Test Coin") || $0.symbol.contains("COIN1") })
    }
    
    func testSearchCaseInsensitiveAndPrefix() {
        // Given
        let exp = expectation(description: "case-insensitive received")
        var results: [Coin] = []
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
        viewModel.updateSearchText("coin2")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertTrue(results.contains { $0.symbol.lowercased().hasPrefix("coin2") || $0.name.lowercased().contains("coin2") })
    }
    
    func testSearchTrimsWhitespaceAndRejectsNonAlphanumerics() {
        // Given
        let emptyExp = expectation(description: "empty received")
        var results: [Coin] = [TestDataFactory.createMockCoin()]
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
        viewModel.updateSearchText("   @@@   ")
        wait(for: [emptyExp], timeout: 1.0)
        
        // Then
        XCTAssertTrue(results.isEmpty)
    }
    
    func testMaxSearchResultsLimit() {
        // Given
        let manyCoins = TestDataFactory.createMockCoins(count: 200)
        mockPersistence.saveCoinList(manyCoins)
        viewModel.refreshSearchData()
        let exp = expectation(description: "limited results")
        var count = 0
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
        viewModel.updateSearchText("COIN")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertLessThanOrEqual(count, 50)
    }
    
    // MARK: - Error State Transitions
    
    func testSharedErrorPublishesFriendlyMessage() {
        // Given
        let exp = expectation(description: "error message received")
        var message: String?
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
        mockShared.emitError(NetworkError.invalidResponse)
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertNotNil(message)
    }
    
    // MARK: - Popular Coins
    
    func testPopularCoinsSwitchingAndLoading() {
        // Given
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 100)
        let exp = expectation(description: "popular coins loaded")
        var received: [Coin] = []
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
        viewModel.updatePopularCoinsFilter(.topGainers)
        viewModel.fetchFreshPopularCoins(for: .topGainers)
        wait(for: [exp], timeout: 3.0)
        
        // Then
        XCTAssertFalse(received.isEmpty)
        XCTAssertTrue(viewModel.isPopularCoinsCacheValid)
    }
}
