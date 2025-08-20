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
        // Verify the view model was created successfully
        XCTAssertNotNil(viewModel)
        // Verify watchlist starts empty
        XCTAssertEqual(viewModel.currentWatchlistCoins.count, 0)
        // Verify no logos are cached initially
        XCTAssertEqual(viewModel.currentCoinLogos.count, 0)
        // Verify not in loading state initially
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadInitialDataWithCoins() {
        // Given
        // Create test coins and set them up in both watchlist and shared data
        let coins = createTestCoins(count: 3)
        // Configure watchlist manager with test coins
        mockWatchlistManager.setMockWatchlist(coins)
        // Configure shared data manager with the same coins (for quote data)
        mockSharedDataManager.setMockCoins(coins)
        
        // When
        viewModel.loadInitialData()
        wait(0.5)
        
        // Then - Verify data is loaded via direct state
        // Verify all 3 coins are loaded in the watchlist
        XCTAssertEqual(viewModel.getWatchlistCount(), 3)
        // Verify loading state is finished
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    func testLoadInitialDataWithEmptyWatchlist() {
        // Given
        // Configure empty watchlist to test empty state handling
        mockWatchlistManager.setMockWatchlist([])
        
        // When
        viewModel.loadInitialData()
        wait(0.5)
        
        // Then
        // Verify empty state is handled correctly
        XCTAssertEqual(viewModel.currentWatchlistCoins.count, 0)
        // Verify loading completes even with empty watchlist
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Watchlist Operations Tests
    
    func testRemoveFromWatchlist() {
        // Given
        // Set up watchlist with 3 test coins
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        // Select the middle coin for removal testing
        let coinToRemove = coins[1]
        
        // Verify initial state before removal
        XCTAssertEqual(viewModel.getWatchlistCount(), 3)
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coinToRemove.id))
        
        // When
        // Remove the selected coin from watchlist
        viewModel.removeFromWatchlist(coinToRemove)
        wait(0.5)
        
        // Then
        // Verify count decreased by 1
        XCTAssertEqual(viewModel.getWatchlistCount(), 2)
        // Verify the removed coin is no longer in watchlist
        XCTAssertFalse(viewModel.isInWatchlist(coinId: coinToRemove.id))
        // Verify the other coins remain in watchlist
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coins[0].id))
        XCTAssertTrue(viewModel.isInWatchlist(coinId: coins[2].id))
    }
    
    func testRemoveFromWatchlistByIndex() {
        // Given
        // Set up watchlist and load data to test index-based removal
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        // Load initial data to populate the VM's coin list
        viewModel.loadInitialData()
        wait(0.5)
        
        // When
        // Remove coin at index 1 (second coin in the list)
        viewModel.removeFromWatchlist(at: 1)
        wait(0.5)
        
        // Then
        XCTAssertEqual(viewModel.getWatchlistCount(), 2)
    }
    
    func testRemoveFromWatchlistWithInvalidIndex() {
        // Given
        // Test error handling for invalid index removal
        let coins = createTestCoins(count: 2)
        mockWatchlistManager.setMockWatchlist(coins)
        // Capture initial count to verify no change after invalid operation
        let initialCount = viewModel.getWatchlistCount()
        
        // When
        // Attempt to remove at invalid index (999)
        viewModel.removeFromWatchlist(at: 999)
        wait(0.5)
        
        // Then - Count should not change
        // Verify invalid index operation didn't affect the watchlist
        XCTAssertEqual(viewModel.getWatchlistCount(), initialCount)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Given
        // Test that network errors are properly handled and displayed to users
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
        // Simulate a network error from the shared data manager
        mockSharedDataManager.emitError(NetworkError.invalidResponse)
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify error was received and displayed
        XCTAssertTrue(errorReceived)
        // Verify loading state was stopped after error
        XCTAssertFalse(viewModel.currentIsLoading)
    }
    
    // MARK: - Sorting Tests
    
    func testSortingConfiguration() {
        // Given
        // Test that sorting configuration changes are properly tracked
        let coins = createTestCoins(count: 3)
        mockWatchlistManager.setMockWatchlist(coins)
        mockSharedDataManager.setMockCoins(coins)
        // Load data to enable sorting operations
        viewModel.loadInitialData()
        wait(0.5)
        
        // When - Test different sort configurations
        // Test sorting by rank in ascending order
        viewModel.updateSorting(column: .rank, order: .ascending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .rank)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .ascending)
        
        // Test sorting by price in descending order
        viewModel.updateSorting(column: .price, order: .descending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .price)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .descending)
        
        // Test sorting by market cap in ascending order
        viewModel.updateSorting(column: .marketCap, order: .ascending)
        XCTAssertEqual(viewModel.getCurrentSortColumn(), .marketCap)
        XCTAssertEqual(viewModel.getCurrentSortOrder(), .ascending)
    }
    
    // MARK: - Filter Tests
    
    func testPriceChangeFilterUpdates() {
        // Given
        // Test that price change filter updates are properly tracked
        let initialFilter = viewModel.currentFilterState.priceChangeFilter
        
        // When/Then - Test filter changes
        // Test switching to 1-hour price change filter
        viewModel.updatePriceChangeFilter(.oneHour)
        XCTAssertEqual(viewModel.currentFilterState.priceChangeFilter, .oneHour)
        XCTAssertNotEqual(viewModel.currentFilterState.priceChangeFilter, initialFilter)
        
        // Test switching to 7-day price change filter
        viewModel.updatePriceChangeFilter(.sevenDays)
        XCTAssertEqual(viewModel.currentFilterState.priceChangeFilter, .sevenDays)
        
        // Test switching to 30-day price change filter
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
        // Test that performance metrics are available for debugging and monitoring
        let metrics = viewModel.getPerformanceMetrics()
        
        // Then - Verify all expected metrics exist
        // Verify watchlist size metrics
        XCTAssertNotNil(metrics["watchlistCount"])
        // Verify logo caching metrics
        XCTAssertNotNil(metrics["logosCached"])
        XCTAssertNotNil(metrics["logoRequestsInProgress"])
        // Verify price update metrics
        XCTAssertNotNil(metrics["lastPriceUpdate"])
        XCTAssertNotNil(metrics["isPriceUpdateInProgress"])
        // Verify loading state metrics
        XCTAssertNotNil(metrics["isLoading"])
        // Verify underlying manager metrics
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
