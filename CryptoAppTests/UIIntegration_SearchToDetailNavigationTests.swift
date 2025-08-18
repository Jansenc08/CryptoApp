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
        let exp = expectation(description: "search results then detail init")
        var firstResult: Coin?
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
        searchVM.updateSearchText("COIN1")
        wait(for: [exp], timeout: 2.0)
        
        // Then - init CoinDetailsVM for selected coin
        XCTAssertNotNil(firstResult)
        let detailsVM = CoinDetailsVM(
            coin: firstResult!,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            requestManager: MockRequestManager()
        )
        // Verify details VM can map range
        XCTAssertEqual(detailsVM.mapRangeToDays("24h"), "1")
    }
}
