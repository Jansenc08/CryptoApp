//
//  SharedCoinDataManagerTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for SharedCoinDataManager covering core behaviors and state transitions.
//  Scope covered:
//  - Initial fetch success path (coins published, loading flags toggle, fresh-data flag toggles)
//  - Initial fetch failure path (error published, loading flags reset, no coins published)
//  - Quotes update path (existing coins updated with fresh quotes on forceUpdate)
//  - ID filtering helper (getCoinsForIds)
//  - Stop auto update resets loading flags
//  Test patterns:
//  - Uses MockCoinManager with controllable delay and outcome
//  - Expectations are guarded with Combine operators (filter/prefix) to avoid multi-fulfill
//  - Manager auto-starts updates in init; tests account for this by creating it after mocks are configured
//

import XCTest
import Combine
@testable import CryptoApp

final class SharedCoinDataManagerTests: XCTestCase {
    
    private var manager: SharedCoinDataManager!
    private var mockCoinManager: MockCoinManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCoinManager = MockCoinManager()
        cancellables = []
        // Manager is created per-test after configuring mocks
        manager = nil
    }
    
    override func tearDown() {
        cancellables.removeAll()
        manager?.stopAutoUpdate()
        manager = nil
        mockCoinManager = nil
        super.tearDown()
    }
    
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    // MARK: - Initial Fetch
    
    func testOnInitFetchesCoinsAndTogglesLoadingStates() {
        // Given
        // Create a sizable dataset to simulate an initial load scenario
        // Configure a small delay to make publisher timing deterministic
        let coins = TestDataFactory.createMockCoins(count: 60)
        mockCoinManager.mockCoins = coins
        mockCoinManager.mockDelay = 0.05
        // Creating the manager triggers the initial fetch automatically
        manager = SharedCoinDataManager(coinManager: mockCoinManager)
        
        // Expect: coins are published once, loading and fresh-data flags toggle true -> false
        let coinsExp = expectation(description: "coins received")
        var receivedCoins: [Coin] = []
        manager.allCoins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { list in
                receivedCoins = list
                coinsExp.fulfill()
            }
            .store(in: &cancellables)
        
        let loadingExp = expectation(description: "loading toggled true->false")
        loadingExp.expectedFulfillmentCount = 2
        var loadingStates: [Bool] = []
        manager.isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count <= 2 { loadingExp.fulfill() }
            }
            .store(in: &cancellables)
        
        let freshExp = expectation(description: "fresh toggled true->false")
        freshExp.expectedFulfillmentCount = 2
        var freshStates: [Bool] = []
        manager.isFetchingFreshData
            .sink { isFresh in
                freshStates.append(isFresh)
                if freshStates.count <= 2 { freshExp.fulfill() }
            }
            .store(in: &cancellables)
        
        // When
        // init already triggered fetch; just wait for expectations to complete
        wait(for: [coinsExp, loadingExp, freshExp], timeout: 3.0)
        
        // Then
        // Verify the full initial dataset is received and flags toggled as expected
        XCTAssertEqual(receivedCoins.count, 60)
        XCTAssertTrue(loadingStates.contains(true))
        XCTAssertTrue(loadingStates.contains(false))
        XCTAssertTrue(freshStates.contains(true))
        XCTAssertTrue(freshStates.contains(false))
    }
    
    func testOnInitFailureEmitsErrorAndResetsLoadingStates() {
        // Given
        // Simulate a failure on the initial fetch path
        mockCoinManager.shouldSucceed = false
        mockCoinManager.mockDelay = 0.05
        // Creating the manager triggers the (failing) initial fetch
        manager = SharedCoinDataManager(coinManager: mockCoinManager)
        
        let errorExp = expectation(description: "error emitted")
        var errorReceived = false
        manager.errors
            .prefix(1)
            .sink { _ in
                errorReceived = true
                errorExp.fulfill()
            }
            .store(in: &cancellables)
        
        let loadingExp = expectation(description: "loading toggled true->false")
        loadingExp.expectedFulfillmentCount = 2
        var loadingStates: [Bool] = []
        manager.isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count <= 2 { loadingExp.fulfill() }
            }
            .store(in: &cancellables)
        
        let freshExp = expectation(description: "fresh toggled true->false")
        freshExp.expectedFulfillmentCount = 2
        var freshStates: [Bool] = []
        manager.isFetchingFreshData
            .sink { isFresh in
                freshStates.append(isFresh)
                if freshStates.count <= 2 { freshExp.fulfill() }
            }
            .store(in: &cancellables)
        
        // When
        // Wait for initial attempt which fails and emits error + resets flags
        wait(for: [errorExp, loadingExp, freshExp], timeout: 3.0)
        
        // Then
        // Verify an error was emitted and both flags toggled true -> false
        XCTAssertTrue(errorReceived)
        XCTAssertTrue(loadingStates.contains(true))
        XCTAssertTrue(loadingStates.contains(false))
        XCTAssertTrue(freshStates.contains(true))
        XCTAssertTrue(freshStates.contains(false))
        XCTAssertTrue(manager.currentCoins.isEmpty)
    }
    
    // MARK: - Quotes Update
    
    func testForceUpdateUpdatesQuotesForExistingCoins() {
        // Given
        // Seed initial list so that subsequent updates go through the quotes-only path
        let initialCoins = TestDataFactory.createMockCoins(count: 10)
        mockCoinManager.mockCoins = initialCoins
        mockCoinManager.mockDelay = 0.01
        manager = SharedCoinDataManager(coinManager: mockCoinManager)
        
        // Wait for the initial emission before triggering a force update
        let initialExp = expectation(description: "initial coins received")
        manager.allCoins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in initialExp.fulfill() }
            .store(in: &cancellables)
        wait(for: [initialExp], timeout: 3.0)
        
        // Prepare fresh quotes for a subset (IDs 1 and 2)
        let dateString = ISO8601DateFormatter().string(from: Date())
        let updatedQuote = Quote(
            price: 60000,
            volume24h: 30000000000,
            volumeChange24h: 6.0,
            percentChange1h: 0.7,
            percentChange24h: 3.0,
            percentChange7d: 18.0,
            percentChange30d: 28.0,
            percentChange60d: nil,
            percentChange90d: nil,
            marketCap: 960000000000,
            marketCapDominance: 43.0,
            fullyDilutedMarketCap: 1060000000000,
            lastUpdated: dateString
        )
        mockCoinManager.mockQuotes = [1: updatedQuote, 2: updatedQuote]
        
        // Expect
        // After forceUpdate, prices for ids 1 and 2 should reflect the new quote
        let updateExp = expectation(description: "quotes updated")
        var updatedCoins: [Coin] = []
        manager.allCoins
            .dropFirst() // skip initial emission
            .prefix(1)
            .sink { list in
                updatedCoins = list
                updateExp.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        manager.forceUpdate()
        wait(for: [updateExp], timeout: 3.0)
        
        // Then
        // Verify targeted coins received updated USD quote prices
        let coin1 = updatedCoins.first { $0.id == 1 }
        let coin2 = updatedCoins.first { $0.id == 2 }
        XCTAssertEqual(coin1?.quote?["USD"]?.price, 60000)
        XCTAssertEqual(coin2?.quote?["USD"]?.price, 60000)
    }
    
    // MARK: - Helpers
    
    func testGetCoinsForIdsReturnsOnlyMatchingIds() {
        // Given
        // Seed a known set of coins to test filtering helper
        let coins = TestDataFactory.createMockCoins(count: 10)
        mockCoinManager.mockCoins = coins
        mockCoinManager.mockDelay = 0.01
        manager = SharedCoinDataManager(coinManager: mockCoinManager)
        
        // Wait for initial state before invoking helper
        let exp = expectation(description: "initial coins received")
        manager.allCoins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        wait(for: [exp], timeout: 3.0)
        
        // When
        // Request a mix of existing and non-existing IDs
        let filtered = manager.getCoinsForIds([1, 3, 999])
        
        // Then
        // Verify only existing IDs are returned (1 and 3)
        let ids = Set(filtered.map { $0.id })
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(ids.contains(1))
        XCTAssertTrue(ids.contains(3))
    }
    
    func testStopAutoUpdateResetsLoadingStatesToFalse() {
        // Given
        // Create manager and immediately stop updates to verify state reset behavior
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 5)
        manager = SharedCoinDataManager(coinManager: mockCoinManager)
        manager.stopAutoUpdate()
        
        // Expect
        // Both loading flags should be set to false after stopping
        let loadingExp = expectation(description: "loading false after stop")
        let freshExp = expectation(description: "fresh false after stop")
        
        manager.isLoading
            .prefix(1)
            .sink { isLoading in
                XCTAssertFalse(isLoading)
                loadingExp.fulfill()
            }
            .store(in: &cancellables)
        
        manager.isFetchingFreshData
            .prefix(1)
            .sink { isFresh in
                XCTAssertFalse(isFresh)
                freshExp.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [loadingExp, freshExp], timeout: 1.0)
    }
}


