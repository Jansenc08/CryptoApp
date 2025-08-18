//
//  UIIntegration_WatchlistFlowTests.swift
//  CryptoAppTests
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
        guard let coin = mockShared.currentCoins.first else {
            XCTFail("No shared coins available for test"); return
        }
        let addExp = expectation(description: "watchlist add reflected in UI")
        let removeExp = expectation(description: "watchlist remove reflected in UI")
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
        mockWatchlist.addToWatchlist(coin, logoURL: nil)
        // Re-emit shared data so VM filters and updates
        mockShared.setMockCoins(mockShared.currentCoins)
        wait(for: [addExp], timeout: 3.0)
        
        // When - Remove via manager using coinId
        mockWatchlist.removeFromWatchlist(coinId: coin.id)
        mockShared.setMockCoins(mockShared.currentCoins)
        wait(for: [removeExp], timeout: 3.0)
    }
}
