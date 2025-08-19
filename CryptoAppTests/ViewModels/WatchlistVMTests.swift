//
//  WatchlistVMTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Simplified and reliable unit tests for WatchlistVM covering core functionality:
//  - Initialization and dependency setup
//  - Data loading and state management
//  - Watchlist operations (add, remove, check membership)
//  - Sorting and filtering
//  - Error handling
//  Test patterns:
//  - Uses direct state testing where possible to avoid timing issues
//  - Simple expectations for async operations
//  - Focuses on testing business logic over reactive plumbing
//

import XCTest
import Combine
@testable import CryptoApp

final class WatchlistVMTests: XCTestCase {
    
    private var viewModel: WatchlistVM!
    private var mockWatchlistManager: MockWatchlistManager!
    private var mockCoinManager: MockCoinManager!
    private var mockSharedDataManager: MockSharedCoinDataManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Initialize mocks
        mockWatchlistManager = MockWatchlistManager()
        mockCoinManager = MockCoinManager()
        mockSharedDataManager = MockSharedCoinDataManager()
        cancellables = []
        
        // Create view model with dependencies
        viewModel = WatchlistVM(
            watchlistManager: mockWatchlistManager,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockSharedDataManager
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        viewModel.cancelAllRequests()
        viewModel = nil
        mockWatchlistManager = nil
        mockCoinManager = nil
        mockSharedDataManager = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    private func createTestCoins(count: Int = 3) -> [Coin] {
        return (1...count).map { index in
            TestDataFactory.createMockCoin(
                id: index,
                symbol: "COIN\(index)",
                name: "Test Coin \(index)",
                rank: index
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Then - Verify initial state
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.currentWatchlistCoins.count, 0)
        XCTAssertEqual(viewModel.currentCoinLogos.count, 0)
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadInitialDataWithCoins() {
        // Given
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        
        // When
        viewModel.loadInitialData()
        wait(0.5)
        
        // Then - Verify data is loaded via direct state
        XCTAssertEqual(viewModel.getWatchlistCount(), 3)
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    func testLoadInitialDataWithEmptyWatchlist() {
        // Given
        mockWatchlistManager.setMockWatchlist([])
        
        // When
        viewModel.loadInitialData()
        wait(0.5)
        
        // Then
        XCTAssertEqual(viewModel.currentWatchlistCoins.count, 0)
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Watchlist Operations Tests
    
    func testRemoveFromWatchlist() {
        // Given
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        let coinToRemove = coins[1]
        
        // Verify initial state
        XCTAssertEqual(viewModel.getWatchlistCount(), 3)
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coinToRemove.id))
        
        // When
        viewModel.removeFromWatchlist(coinToRemove)
        wait(0.5)
        
        // Then
        XCTAssertEqual(viewModel.getWatchlistCount(), 2)
        XCTAssertFalse(viewModel.isInWatchlist(coinId: coinToRemove.id))
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coins[0].id))
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coins[2].id))
    }
    
    func testRemoveFromWatchlistByIndex() {
        // Given
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        viewModel.loadInitialData()
        wait(0.5)
        
        // When
        viewModel.removeFromWatchlist(at: 1)
        wait(0.5)
        
        // Then
        XCTAssertEqual(viewModel.getWatchlistCount(), 2)
    }
    
    func testRemoveFromWatchlistWithInvalidIndex() {
        // Given
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        let initialCount = viewModel.getWatchlistCount()
        
        // When
        viewModel.removeFromWatchlist(at: 999)
        wait(0.5)
        
        // Then - Count should not change
        XCTAssertEqual(viewModel.getWatchlistCount(), initialCount)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Given
        var errorReceived = false
        let exp = expectation(description: "error received")
        
        viewModel.errorMessage
            .sink { message in
                if message != nil {
                    errorReceived = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSharedDataManager.emitError(NetworkError.invalidResponse)
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertTrue(errorReceived)
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Sorting Tests
    
    func testSortingConfiguration() {
        // Given
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        viewModel.loadInitialData()
        wait(0.5)
        
        // When - Test different sort configurations
        viewModel.updateSorting(column: .rank, order: .ascending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .rank)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .ascending)
        
        viewModel.updateSorting(column: .price, order: .descending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .price)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .descending)
        
        viewModel.updateSorting(column: .marketCap, order: .ascending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .marketCap)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .ascending)
    }
    
    // MARK: - Filter Tests
    
    func testPriceChangeFilterUpdates() {
        // Given
        let initialFilter = viewModel.currentFilterState.priceChangeFilter
        
        // When/Then - Test filter changes
        viewModel.updatePriceChangeFilter(.oneHour)
        XCTAssertEqual(viewModel.currentFilterState.priceChangeFilter, .oneHour)
        XCTAssertNotEqual(viewModel.currentFilterState.priceChangeFilter, initialFilter)
        
        viewModel.updatePriceChangeFilter(.sevenDays)
        XCTAssertEqual(viewModel.currentFilterState.priceChangeFilter, .sevenDays)
        
        viewModel.updatePriceChangeFilter(.thirtyDays)
        XCTAssertEqual(viewModel.currentFilterState.priceChangeFilter, .thirtyDays)
    }
    
    // MARK: - Logo Management Tests
    
    func testLogoFetching() {
        // Given
        let coins = createTestCoins(count: 2)
        let mockLogos = TestDataFactory.createMockLogos(for: [1, 2])
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        mockCoinManager.mockLogos = mockLogos
        
        var logosReceived = false
        let exp = expectation(description: "logos received")
        
        viewModel.coinLogos
            .sink { logos in
                if !logos.isEmpty {
                    logosReceived = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.loadInitialData()
        wait(for: [exp], timeout: 3.0)
        
        // Then
        XCTAssertTrue(logosReceived)
    }
    
    // MARK: - Price Change Detection Tests
    
    func testPriceChangeDetection() {
        // Given
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        viewModel.loadInitialData()
        wait(0.5)
        
        // Create updated coins with price changes
        var updatedCoins = coins
        if var coin = updatedCoins.first,
           let oldQuote = coin.quote?["USD"] {
            let newQuote = Quote(
                price: (oldQuote.price ?? 0) + 1000.0,
                volume24h: oldQuote.volume24h,
                volumeChange24h: oldQuote.volumeChange24h,
                percentChange1h: oldQuote.percentChange1h,
                percentChange24h: oldQuote.percentChange24h,
                percentChange7d: oldQuote.percentChange7d,
                percentChange30d: oldQuote.percentChange30d,
                percentChange60d: oldQuote.percentChange60d,
                percentChange90d: oldQuote.percentChange90d,
                marketCap: oldQuote.marketCap,
                marketCapDominance: oldQuote.marketCapDominance,
                fullyDilutedMarketCap: oldQuote.fullyDilutedMarketCap,
                lastUpdated: oldQuote.lastUpdated
            )
            coin.quote?["USD"] = newQuote
            updatedCoins[0] = coin
        }
        
        var changeDetected = false
        let exp = expectation(description: "price change detected")
        
        viewModel.updatedCoinIds
            .sink { ids in
                if !ids.isEmpty {
                    changeDetected = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        mockSharedDataManager.setMockCoins(updatedCoins)
        wait(for: [exp], timeout: 2.0)
        
        // Then
        XCTAssertTrue(changeDetected)
    }
    
    // MARK: - Lifecycle Tests
    
    func testLifecycleMethods() {
        // When - Test lifecycle methods don't crash
        viewModel.startPeriodicUpdates()
        viewModel.stopPeriodicUpdates()
        viewModel.cancelAllRequests()
        
        // Then
        XCTAssertNotNil(viewModel)
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testPerformanceMetrics() {
        // When
        let metrics = viewModel.getPerformanceMetrics()
        
        // Then - Verify all expected metrics exist
        XCTAssertNotNil(metrics["watchlistCount"])
        XCTAssertNotNil(metrics["logosCached"])
        XCTAssertNotNil(metrics["logoRequestsInProgress"])
        XCTAssertNotNil(metrics["lastPriceUpdate"])
        XCTAssertNotNil(metrics["isPriceUpdateInProgress"])
        XCTAssertNotNil(metrics["isLoading"])
        XCTAssertNotNil(metrics["watchlistManagerMetrics"])
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshWatchlist() {
        // Given
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        
        // When
        viewModel.refreshWatchlist()
        wait(0.5)
        
        // Then
        XCTAssertEqual(viewModel.getWatchlistCount(), 2)
    }
    
    func testRefreshWatchlistSilently() {
        // Given
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        
        var loadingStates: [Bool] = []
        viewModel.isLoading
            .sink { loading in
                loadingStates.append(loading)
            }
            .store(in: &cancellables)
        
        // When
        viewModel.refreshWatchlistSilently()
        wait(0.5)
        
        // Then - Should not trigger loading state
        XCTAssertTrue(loadingStates.allSatisfy { !$0 })
    }
    
    // MARK: - Edge Cases Tests
    
    func testForceUpdateWhenNoSharedData() {
        // Given
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        // No shared data set
        
        var loadingTriggered = false
        viewModel.isLoading
            .sink { loading in
                if loading {
                    loadingTriggered = true
                }
            }
            .store(in: &cancellables)
        
        // When
        viewModel.loadInitialData()
        wait(0.5)
        
        // Then
        XCTAssertTrue(loadingTriggered)
    }
    
    func testClearUpdatedCoinIds() {
        // Given/When
        viewModel.clearUpdatedCoinIds()
        wait(0.5)
        
        // Then - Should not crash
        XCTAssertNotNil(viewModel)
    }
}
