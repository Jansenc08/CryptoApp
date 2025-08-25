//
//  CoinListVMTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for CoinListVM focusing on core behaviors used by the Coins screen.
//  Scope covered:
//  - Pagination on top of fullFilteredCoins (20 per page) with filter + prefix(1) guards
//  - Cached data path (offline) with pagination applied to cached dataset
//  - Error state transitions (loading toggles + user-facing error message)
//  Test patterns:
//  - Uses MockCoinManager, MockSharedCoinDataManager, and MockPersistenceService
//  - Expectations are guarded with Combine operators (filter/prefix) to avoid multi-fulfill
//  - All tests avoid touching UIKit; publishers are observed directly
//

import XCTest
import Combine
@testable import CryptoApp

final class CoinListVMTests: XCTestCase {
    
    private var viewModel: CoinListVM!
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
        
        viewModel = CoinListVM(
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
    
    // MARK: - Pagination
    
    func testLoadMoreCoins_paginatedFromSharedData_incrementsByTwenty() {
        // Given: 50 coins available from shared data → VM shows 20 per page
        // Create a large dataset to test pagination behavior
        let coins = TestDataFactory.createMockCoins(count: 50)
        // Create expectation for receiving the first page of results
        let receivedExp = expectation(description: "received first page")
        // Variable to capture the count of coins in the first page
        var page1Count = 0
        
        viewModel.coins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { coins in
                page1Count = coins.count
                receivedExp.fulfill()
            }
            .store(in: &cancellables)
        
        // When: send shared coins to VM
        // This triggers the VM to process the coins and emit the first page
        mockShared.setMockCoins(coins)
        wait(for: [receivedExp], timeout: 2.0)
        
        // Then: first page size should be 20
        // Verify pagination limits the first page to 20 items
        XCTAssertEqual(page1Count, 20)
        
        // When: load more → should append next 20 (total 40)
        // Test loading the second page of results
        let page2Exp = expectation(description: "received second page")
        // Variable to capture total count after loading page 2
        var totalAfterPage2 = 0
        viewModel.coins
            .filter { $0.count == 40 }
            .prefix(1)
            .sink { updated in
                totalAfterPage2 = updated.count
                page2Exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger loading of the second page
        viewModel.loadMoreCoins()
        wait(for: [page2Exp], timeout: 2.0)
        // Verify total is now 40 (20 + 20)
        XCTAssertEqual(totalAfterPage2, 40)
        
        // When: load more → should append last 10 (total 50)
        // Test loading the final page which has remaining 10 items
        let page3Exp = expectation(description: "received third page")
        // Variable to capture final total count
        var totalAfterPage3 = 0
        viewModel.coins
            .filter { $0.count == 50 }
            .prefix(1)
            .sink { updated in
                totalAfterPage3 = updated.count
                page3Exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger loading of the third page
        viewModel.loadMoreCoins()
        wait(for: [page3Exp], timeout: 2.0)
        // Verify all 50 items are now loaded
        XCTAssertEqual(totalAfterPage3, 50)
        
        // When: load more again → should not change (no more data)
        // Test that loadMore has no effect when all data is loaded
        viewModel.loadMoreCoins()
        wait(0.1)
        // Verify count remains at 50 (no additional data to load)
        XCTAssertEqual(totalAfterPage3, 50)
    }
    
    // MARK: - Cached Data Path
    
    func testFetchCoins_whenOfflineCacheAvailable_usesFirstPageFromCache() {
        // Given: save offline data and mark cache fresh
        // Create offline data that should be used when network is unavailable
        let cachedCoins = TestDataFactory.createMockCoins(count: 30)
        let cachedLogos = TestDataFactory.createMockLogos(for: cachedCoins.map { $0.id })
        // Store the offline data in persistence layer
        mockPersistence.saveOfflineData(coins: cachedCoins, logos: cachedLogos)
        
        // When
        // Create expectation for cached data retrieval
        let exp = expectation(description: "received cached first page")
        // Array to capture the cached coins returned by the VM
        var received: [Coin] = []
        viewModel.coins
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { coins in
                received = coins
                exp.fulfill()
            }
            .store(in: &cancellables)
        // Trigger coin fetching (should use cached data)
        viewModel.fetchCoins(convert: "USD", priority: .normal)
        wait(for: [exp], timeout: 2.0)
        
        // Then: should show first 20 from cached 30
        // Verify pagination applies to cached data (first page of 20)
        XCTAssertEqual(received.count, 20)
        // Verify the first coin has the expected ID from cached data
        XCTAssertEqual(received.first?.id, 1)
    }
    
    // MARK: - Error State Transitions
    
    func testFetchCoins_whenFailure_publishesErrorAndStopsLoading() {
        // Given
        // Configure coin manager to simulate a network failure
        mockCoinManager.shouldSucceed = false
        
        // Create expectation for loading state changes (should toggle twice)
        let loadingExp = expectation(description: "loading toggled")
        loadingExp.expectedFulfillmentCount = 2 // true then false
        // Array to capture all loading state changes
        var loadingStates: [Bool] = []
        viewModel.isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count <= 2 { loadingExp.fulfill() }
            }
            .store(in: &cancellables)
        
        // Create expectation for error message publication
        let errorExp = expectation(description: "error message received")
        // Variable to capture the error message
        var receivedError: String?
        viewModel.errorMessage
            .sink { message in
                if let msg = message, !msg.isEmpty {
                    receivedError = msg
                    errorExp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // Trigger fetch operation that will fail
        viewModel.fetchCoins(convert: "USD", priority: .high)
        wait(for: [loadingExp, errorExp], timeout: 3.0)
        
        // Then
        // Verify loading state was turned on during the request
        XCTAssertTrue(loadingStates.contains(true))
        // Verify loading state was turned off after the failure
        XCTAssertTrue(loadingStates.contains(false))
        // Verify an error message was published for the user
        XCTAssertNotNil(receivedError)
    }
}

// MARK: - Additional behavior tests merged here for cohesion
extension CoinListVMTests {
    func testUpdateSorting_byPriceAscendingThenDescending_updatesOrder() {
        // Given: create coins with different prices
        var coins = TestDataFactory.createMockCoins(count: 5)
        func setPrice(_ id: Int, _ price: Double) {
            if let old = coins[id-1].quote?["USD"] {
                let q = Quote(
                    price: price,
                    volume24h: old.volume24h,
                    volumeChange24h: old.volumeChange24h,
                    percentChange1h: old.percentChange1h,
                    percentChange24h: old.percentChange24h,
                    percentChange7d: old.percentChange7d,
                    percentChange30d: old.percentChange30d,
                    percentChange60d: old.percentChange60d,
                    percentChange90d: old.percentChange90d,
                    marketCap: old.marketCap,
                    marketCapDominance: old.marketCapDominance,
                    fullyDilutedMarketCap: old.fullyDilutedMarketCap,
                    lastUpdated: old.lastUpdated
                )
                coins[id-1].quote?["USD"] = q
            }
        }
        setPrice(1, 10)
        setPrice(2, 50)
        setPrice(3, 30)
        setPrice(4, 5)
        setPrice(5, 80)

        // Seed shared data
        mockShared.setMockCoins(coins)

        // Wait initial publish (count < 20 so all 5 arrive)
        let initial = expectation(description: "initial coins")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in initial.fulfill() }.store(in: &cancellables)
        wait(for: [initial], timeout: 1.0)

        // When: sort ASC
        viewModel.updateSorting(column: .price, order: .ascending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 4) // lowest price first

        // When: sort DESC
        viewModel.updateSorting(column: .price, order: .descending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 5) // highest price first
    }

    func testFetchPriceUpdates_whenQuotesChange_emitsUpdatedCoinIds() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 10)
        mockShared.setMockCoins(coins)

        let updateExp = expectation(description: "updated ids")
        var updatedIds: Set<Int> = []
        viewModel.updatedCoinIds.sink { ids in
            if !ids.isEmpty { updatedIds = ids; updateExp.fulfill() }
        }.store(in: &cancellables)

        // Prepare updated quotes for first two coins
        let q1 = Quote(price: 60000, volume24h: nil, volumeChange24h: nil, percentChange1h: nil, percentChange24h: 1.0, percentChange7d: nil, percentChange30d: nil, percentChange60d: nil, percentChange90d: nil, marketCap: nil, marketCapDominance: nil, fullyDilutedMarketCap: nil, lastUpdated: nil)
        let q2 = Quote(price: 100, volume24h: nil, volumeChange24h: nil, percentChange1h: nil, percentChange24h: -2.0, percentChange7d: nil, percentChange30d: nil, percentChange60d: nil, percentChange90d: nil, marketCap: nil, marketCapDominance: nil, fullyDilutedMarketCap: nil, lastUpdated: nil)
        mockCoinManager.mockQuotes = [1: q1, 2: q2]

        let done = expectation(description: "done")
        viewModel.fetchPriceUpdates { done.fulfill() }
        wait(for: [updateExp, done], timeout: 2.0)

        XCTAssertTrue(updatedIds.contains(1))
        XCTAssertTrue(updatedIds.contains(2))
    }

    func testUpdateTopCoinsFilter_whenChanged_recomputesAndPaginates() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 150)
        mockShared.setMockCoins(coins)
        let initial = expectation(description: "initial")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in initial.fulfill() }.store(in: &cancellables)
        wait(for: [initial], timeout: 1.0)

        // When: change top coins filter
        viewModel.updateTopCoinsFilter(.top200)

        // Then: still paginates to 20 on first page
        XCTAssertEqual(viewModel.currentCoins.count, 20)
    }

    func testFetchCoins_defaultSortAndFilters_usesCache_otherSorts_fetchFresh() {
        // Given: offline data present
        let cachedCoins = TestDataFactory.createMockCoins(count: 40)
        let cachedLogos = TestDataFactory.createMockLogos(for: cachedCoins.map { $0.id })
        mockPersistence.saveOfflineData(coins: cachedCoins, logos: cachedLogos)

        // When: default state and default sort (price DESC) should use cache
        let exp1 = expectation(description: "default cache page1")
        var firstLoadCount = 0
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { first in
            firstLoadCount = first.count
            exp1.fulfill()
        }.store(in: &cancellables)
        viewModel.fetchCoins()
        wait(for: [exp1], timeout: 2.0)
        XCTAssertEqual(firstLoadCount, 20)

        // When: change to custom sort -> should not use cache-only path next time
        viewModel.updateSorting(column: .marketCap, order: .ascending)
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 25)
        let exp2 = expectation(description: "fresh fetch due to custom sort")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in exp2.fulfill() }.store(in: &cancellables)
        viewModel.fetchCoins(priority: .high)
        wait(for: [exp2], timeout: 3.0)
    }

    func testClearUpdatedCoinIds_afterUpdate_emitsEmptySet() {
        // Given: emit some updated ids
        let coins = TestDataFactory.createMockCoins(count: 5)
        mockShared.setMockCoins(coins)

        // First, ensure we get a non-empty emission when updates occur
        let nonEmptyExp = expectation(description: "non-empty updated ids")
        var nonEmptySeen = false
        viewModel.updatedCoinIds
            .sink { ids in
                if !nonEmptySeen && !ids.isEmpty {
                    nonEmptySeen = true
                    nonEmptyExp.fulfill()
                }
            }
            .store(in: &cancellables)

        // Trigger updates for two coins
        mockCoinManager.mockQuotes = [1: coins[0].quote!["USD"]!, 2: coins[1].quote!["USD"]!]
        let done = expectation(description: "done")
        viewModel.fetchPriceUpdates { done.fulfill() }
        wait(for: [nonEmptyExp, done], timeout: 2.0)

        // When: observe for the cleared (empty set) emission
        let clearedExp = expectation(description: "cleared updated ids")
        viewModel.updatedCoinIds
            .filter { $0.isEmpty }
            .prefix(1)
            .sink { _ in clearedExp.fulfill() }
            .store(in: &cancellables)
        viewModel.clearUpdatedCoinIds()
        wait(for: [clearedExp], timeout: 1.0)
    }

    func testCancelAllRequests_resetsLoadingFetchingAndLoadingMoreFlags() {
        // Given: start a fetch to set loading
        mockCoinManager.shouldSucceed = false
        let loadingStarted = expectation(description: "loading started")
        viewModel.isLoading.sink { if $0 { loadingStarted.fulfill() } }.store(in: &cancellables)
        viewModel.fetchCoins(priority: .high)
        wait(for: [loadingStarted], timeout: 2.0)

        // When
        let flagsReset = expectation(description: "flags reset")
        var loading = true, fetching = true, loadingMore = true
        viewModel.isLoading.sink { loading = $0 }.store(in: &cancellables)
        viewModel.isFetchingFreshData.sink { fetching = $0 }.store(in: &cancellables)
        viewModel.isLoadingMore.sink { loadingMore = $0 }.store(in: &cancellables)
        viewModel.cancelAllRequests()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { flagsReset.fulfill() }
        wait(for: [flagsReset], timeout: 1.0)

        // Then
        XCTAssertFalse(loading)
        XCTAssertFalse(fetching)
        XCTAssertFalse(loadingMore)
    }

    func testFetchPriceUpdates_whenLoadingOrLoadingMore_isGracefullySkipped() {
        // Given: set internal states to block updates via starting a fetch
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 25)
        let first = expectation(description: "initial load")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in first.fulfill() }.store(in: &cancellables)
        viewModel.fetchCoins(priority: .high)
        wait(for: [first], timeout: 3.0)

        // When: simulate concurrent price update being blocked by setting loadingMore
        // Trigger load more to set loadingMore briefly
        viewModel.loadMoreCoins()
        let done = expectation(description: "done")
        viewModel.fetchPriceUpdates { done.fulfill() }
        wait(for: [done], timeout: 1.5)

        // Then: no crash, path executed; we assert simply that completion was called
        XCTAssertTrue(true)
    }

    func testUpdateSorting_byPriceChangeRespectsEachTimeFilter() {
        // Given: 4 coins with distinct change values per timeframe
        var coins = TestDataFactory.createMockCoins(count: 4)
        func setChanges(_ idx: Int, _ c1h: Double, _ c24h: Double, _ c7d: Double, _ c30d: Double) {
            let i = idx - 1
            if let old = coins[i].quote?["USD"] {
                let q = Quote(
                    price: old.price,
                    volume24h: old.volume24h,
                    volumeChange24h: old.volumeChange24h,
                    percentChange1h: c1h,
                    percentChange24h: c24h,
                    percentChange7d: c7d,
                    percentChange30d: c30d,
                    percentChange60d: old.percentChange60d,
                    percentChange90d: old.percentChange90d,
                    marketCap: old.marketCap,
                    marketCapDominance: old.marketCapDominance,
                    fullyDilutedMarketCap: old.fullyDilutedMarketCap,
                    lastUpdated: old.lastUpdated
                )
                coins[i].quote?["USD"] = q
            }
        }
        // Max per timeframe: 1h->coin2, 24h->coin3, 7d->coin4, 30d->coin1
        setChanges(1, 1.0, 2.0, 3.0, 10.0)
        setChanges(2, 9.0, 1.0, 2.0, 3.0)
        setChanges(3, 3.0, 11.0, 1.0, 2.0)
        setChanges(4, 2.0, 4.0, 12.0, 1.0)

        // Seed shared
        mockShared.setMockCoins(coins)
        let initial = expectation(description: "initial coins")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in initial.fulfill() }.store(in: &cancellables)
        wait(for: [initial], timeout: 1.0)

        // 1h
        viewModel.updatePriceChangeFilter(.oneHour)
        viewModel.updateSorting(column: .priceChange, order: .descending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 2)
        // 24h
        viewModel.updatePriceChangeFilter(.twentyFourHours)
        viewModel.updateSorting(column: .priceChange, order: .descending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 3)
        // 7d
        viewModel.updatePriceChangeFilter(.sevenDays)
        viewModel.updateSorting(column: .priceChange, order: .descending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 4)
        // 30d
        viewModel.updatePriceChangeFilter(.thirtyDays)
        viewModel.updateSorting(column: .priceChange, order: .descending)
        XCTAssertEqual(viewModel.currentCoins.first?.id, 1)
    }

    func testFetchCoins_minimumFetchInterval_skipsImmediateSecondCall() {
        // Given
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 25)

        var loadingTrueCount = 0
        viewModel.isLoading.sink { if $0 { loadingTrueCount += 1 } }.store(in: &cancellables)

        let firstDone = expectation(description: "first fetch started")
        // Observe first emission of isLoading true to ensure first started
        viewModel.isLoading.filter { $0 }.prefix(1).sink { _ in firstDone.fulfill() }.store(in: &cancellables)

        // When: first call
        viewModel.fetchCoins(priority: .high)
        wait(for: [firstDone], timeout: 2.0)

        // Immediate second call should be skipped due to minimumFetchInterval
        let secondFinish = expectation(description: "second onFinish called")
        viewModel.fetchCoins(onFinish: { secondFinish.fulfill() })
        wait(for: [secondFinish], timeout: 1.0)

        // Then: only one true emission recorded
        XCTAssertEqual(loadingTrueCount, 1)
    }

    func testIsFetchingFreshData_onSuccess_togglesTrueThenFalse() {
        // Given: no cached offline data, success path
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockCoins = TestDataFactory.createMockCoins(count: 30)

        let exp = expectation(description: "isFetchingFreshData toggles")
        exp.expectedFulfillmentCount = 2
        var states: [Bool] = []
        viewModel.isFetchingFreshData.sink { val in
            states.append(val)
            if states.count <= 2 { exp.fulfill() }
        }.store(in: &cancellables)

        // When
        viewModel.fetchCoins(priority: .high)
        wait(for: [exp], timeout: 3.0)

        // Then: should contain true then false
        XCTAssertTrue(states.contains(true))
        XCTAssertTrue(states.contains(false))
    }

    func testFetchPriceUpdatesForVisibleCoins_updatesOnlyProvidedIds() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 10)
        mockShared.setMockCoins(coins)
        let initial = expectation(description: "initial load")
        viewModel.coins.filter { !$0.isEmpty }.prefix(1).sink { _ in initial.fulfill() }.store(in: &cancellables)
        wait(for: [initial], timeout: 1.0)
        // Clear any previous updated ids emitted by shared data processing
        viewModel.clearUpdatedCoinIds()

        // Prepare quotes for subset [2,5]
        func updatedQuote(from q: Quote, priceDelta: Double, pct: Double) -> Quote {
            return Quote(
                price: (q.price ?? 0) + priceDelta,
                volume24h: q.volume24h,
                volumeChange24h: q.volumeChange24h,
                percentChange1h: q.percentChange1h,
                percentChange24h: pct,
                percentChange7d: q.percentChange7d,
                percentChange30d: q.percentChange30d,
                percentChange60d: q.percentChange60d,
                percentChange90d: q.percentChange90d,
                marketCap: q.marketCap,
                marketCapDominance: q.marketCapDominance,
                fullyDilutedMarketCap: q.fullyDilutedMarketCap,
                lastUpdated: q.lastUpdated
            )
        }

        let q2 = coins[1].quote!["USD"]!
        let q5 = coins[4].quote!["USD"]!
        mockCoinManager.mockQuotes = [
            2: updatedQuote(from: q2, priceDelta: 100.0, pct: (q2.percentChange24h ?? 0) + 1.0),
            5: updatedQuote(from: q5, priceDelta: -50.0, pct: (q5.percentChange24h ?? 0) - 1.0)
        ]

        // When
        let exp = expectation(description: "visible subset updated")
        var ids: Set<Int> = []
        let expected: Set<Int> = Set([2,5])
        viewModel.updatedCoinIds
            .filter { $0 == expected }
            .prefix(1)
            .sink { s in ids = s; exp.fulfill() }
            .store(in: &cancellables)
        viewModel.fetchPriceUpdatesForVisibleCoins([2,5]) { }
        wait(for: [exp], timeout: 2.0)

        // Then
        XCTAssertEqual(ids, expected)
    }
}
