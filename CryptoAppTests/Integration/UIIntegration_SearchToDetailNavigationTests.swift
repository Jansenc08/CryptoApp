//
//  UIIntegration_SearchToDetailNavigationTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Integration-style VM test mimicking a user searching and then opening a coin detail screen.
//  Steps validated:
//  - SearchVM produces results from cached/shared data
//  - First result is used to initialize CoinDetailsVM
//  - Basic mapping (range to days) works for details VM
//

import XCTest
import Combine
@testable import CryptoApp

final class UIIntegration_SearchToDetailNavigationTests: XCTestCase {
    
    private var searchVM: SearchVM!
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
        
        // Seed cache and shared for search
        let coins = TestDataFactory.createMockCoins(count: 20)
        mockPersistence.saveCoinList(coins)
        mockShared.setMockCoins(coins)
        
        searchVM = SearchVM(coinManager: mockCoinManager, sharedCoinDataManager: mockShared, persistenceService: mockPersistence)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        searchVM.cancelAllRequests()
        searchVM = nil
        mockCoinManager = nil
        mockShared = nil
        mockPersistence = nil
        super.tearDown()
    }
    
    func testSearchToDetailNavigationInitializesDetailsVM() {
        // Given
        // Test the complete user flow from search to coin detail navigation
        // This simulates a user typing in search and selecting a result
        let exp = expectation(description: "search results then detail init")
        // Variable to capture the first search result for detail navigation
        var firstResult: Coin?
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        searchVM.searchResults
            .sink { results in
                if let coin = results.first, !fulfilled {
                    firstResult = coin
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - simulate user typing and selecting first result
        // User types "COIN1" in the search field
        searchVM.updateSearchText("COIN1")
        wait(for: [exp], timeout: 2.0)
        
        // Then - init CoinDetailsVM for selected coin
        // Verify we got a search result to navigate to
        XCTAssertNotNil(firstResult)
        // Create details VM with the selected coin (simulates navigation)
        let detailsVM = CoinDetailsVM(
            coin: firstResult!,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            requestManager: MockRequestManager()
        )
        // Verify details VM is properly initialized and can handle basic operations
        XCTAssertEqual(detailsVM.mapRangeToDays("24h"), "1")
    }
}
