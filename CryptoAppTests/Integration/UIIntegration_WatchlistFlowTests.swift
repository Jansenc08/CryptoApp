//
//  UIIntegration_WatchlistFlowTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Integration-style VM test exercising the Watchlist flow without UIKit.
//  Verifies that add/remove operations in WatchlistManager are reflected by WatchlistVM.watchlistCoins
//  when SharedCoinDataManager emits coins. Uses a coin that exists in shared data to ensure filtering works.
//  Patterns:
//  - Re-emits shared coins after add/remove to drive VM updates
//  - Guards expectations with flags and uses modest timeouts for stability
//

import XCTest
import Combine
@testable import CryptoApp

final class UIIntegration_WatchlistFlowTests: XCTestCase {
    
    private var watchlistVM: WatchlistVM!
    private var mockWatchlist: MockWatchlistManager!
    private var mockCoinManager: MockCoinManager!
    private var mockShared: MockSharedCoinDataManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockWatchlist = MockWatchlistManager()
        mockCoinManager = MockCoinManager()
        mockShared = MockSharedCoinDataManager()
        cancellables = []
        
        // Seed shared data with quotes for UI (ids: 1...10)
        let coins = TestDataFactory.createMockCoins(count: 10)
        mockShared.setMockCoins(coins)
        
        watchlistVM = WatchlistVM(
            watchlistManager: mockWatchlist,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        watchlistVM = nil
        mockWatchlist = nil
        mockCoinManager = nil
        mockShared = nil
        super.tearDown()
    }
    
    func testAddAndRemoveWatchlistFlowUpdatesUI() {
        // Given: choose an existing coin from shared data (ensures VM can resolve it)
        // Test the complete watchlist flow: add coin -> verify UI update -> remove coin -> verify UI update
        guard let coin = mockShared.currentCoins.first else {
            XCTFail("No shared coins available for test"); return
        }
        // Create separate expectations for add and remove operations
        let addExp = expectation(description: "watchlist add reflected in UI")
        let removeExp = expectation(description: "watchlist remove reflected in UI")
        // Flags to prevent multiple expectation fulfillments
        var addFulfilled = false
        var removeFulfilled = false
        
        watchlistVM.watchlistCoins
            .sink { coins in
                if coins.contains(where: { $0.id == coin.id }) && !addFulfilled {
                    addFulfilled = true
                    addExp.fulfill()
                }
                if !coins.contains(where: { $0.id == coin.id }) && addFulfilled && !removeFulfilled {
                    removeFulfilled = true
                    removeExp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When - Add via manager
        // User adds coin to watchlist (simulates tapping add button)
        mockWatchlist.addToWatchlist(coin, logoURL: nil)
        // Re-emit shared data so VM filters and updates (simulates data refresh)
        mockShared.setMockCoins(mockShared.currentCoins)
        wait(for: [addExp], timeout: 3.0)
        
        // When - Remove via manager using coinId
        // User removes coin from watchlist (simulates tapping remove button)
        mockWatchlist.removeFromWatchlist(coinId: coin.id)
        // Re-emit shared data to trigger VM update
        mockShared.setMockCoins(mockShared.currentCoins)
        wait(for: [removeExp], timeout: 3.0)
    }
}
