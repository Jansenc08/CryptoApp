//
//  CoinDetailsVMTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for CoinDetailsVM focusing on chart data loading (line), OHLC loading (candlestick),
//  cache-first behavior, price change indicator emissions, smart auto-refresh, and retry paths.
//  Notes:
//  - Cache is cleared in setUp() to ensure deterministic code paths for error/loading tests
//  - Uses MockCoinManager + MockSharedCoinDataManager + MockRequestManager
//  - Expectations use filter + prefix(1) or flags to avoid multiple-fulfill
//

import XCTest
import Combine
@testable import CryptoApp

final class CoinDetailsVMTests: XCTestCase {
    
    private var viewModel: CoinDetailsVM!
    private var mockCoinManager: MockCoinManager!
    private var mockShared: MockSharedCoinDataManager!
    private var mockRequest: MockRequestManager!
    private var cancellables: Set<AnyCancellable>!
    private var baseCoin: Coin!
    
    override func setUp() {
        super.setUp()
        // Ensure no stale cache interferes with tests
        CacheService.shared.clearCache()
        
        mockCoinManager = MockCoinManager()
        mockShared = MockSharedCoinDataManager()
        mockRequest = MockRequestManager()
        cancellables = []
        
        baseCoin = TestDataFactory.createMockCoin(id: 1, symbol: "BTC", name: "Bitcoin", rank: 1)
        viewModel = CoinDetailsVM(
            coin: baseCoin,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            requestManager: mockRequest
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        viewModel.cancelAllRequests()
        viewModel = nil
        mockCoinManager = nil
        mockShared = nil
        mockRequest = nil
        baseCoin = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }
    
    // MARK: - Chart Data
    
    func testFetchChartData_whenSuccess_emitsChartPoints() {
        // Given
        // Configure coin manager to simulate successful chart data fetch
        mockCoinManager.shouldSucceed = true
        // Provide mock chart data points representing price over time
        mockCoinManager.mockChartData = [100.0, 101.5, 102.3]
        // Create expectation for receiving chart data
        let exp = expectation(description: "chart points received")
        // Array to capture the chart points returned by the VM
        var received: [Double] = []
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { points in
                received = points
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.fetchChartData(for: "24h")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify that chart data was successfully received
        XCTAssertFalse(received.isEmpty)
    }
    
    func testFetchChartData_whenFailure_publishesErrorState() {
        // Given (no cache due to setUp)
        // Configure coin manager to simulate chart data fetch failure
        mockCoinManager.shouldSucceed = false
        // Create expectation for error state publication
        let exp = expectation(description: "error state published")
        // Flag to track if an error state was received
        var gotError = false
        
        viewModel.chartLoadingState
            .sink { state in
                switch state {
                case .error(_), .nonRetryableError(_):
                    gotError = true
                    exp.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // When
        // Trigger chart data fetch that will fail
        viewModel.fetchChartData(for: "24h")
        wait(for: [exp], timeout: 3.0)
        
        // Then
        // Verify that an error state was published to inform the UI
        XCTAssertTrue(gotError)
    }
    
    func testFetchChartData_whenCacheHit_doesNotToggleLoading() {
        // Given: Seed cache for btc 24h -> days "1"
        // Pre-populate cache with chart data to test cache-first behavior
        CacheService.shared.storeChartData([200.0, 201.0], for: "btc", currency: "usd", days: "1")
        // Create expectation for cached data retrieval
        let exp = expectation(description: "cached chart used")
        // Array to capture chart data from cache
        var received: [Double] = []
        // Array to track loading states (should not show loading when using cache)
        var loadingStates: [Bool] = []
        
        viewModel.isLoading
            .sink { loading in loadingStates.append(loading) }
            .store(in: &cancellables)
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { points in
                received = points
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.fetchChartData(for: "24h")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify cached data was returned (first point should be 200.0)
        XCTAssertEqual(received.first, 200.0)
        // Verify no loading state was triggered (cache hit should be instant)
        XCTAssertFalse(loadingStates.contains(true))
    }
    
    // MARK: - OHLC Data
    
    func testFetchChartData_whenSuccess_triggersOHLCDataFetch() {
        // Given
        // Configure successful responses for both chart and OHLC data
        mockCoinManager.shouldSucceed = true
        // Provide basic chart data that will trigger OHLC fetch
        mockCoinManager.mockChartData = [1, 2, 3]
        // Provide mock OHLC (candlestick) data for testing
        mockCoinManager.mockOHLCData = TestDataFactory.createMockOHLCData(candles: 5)
        // Create expectation for OHLC data reception
        let exp = expectation(description: "ohlc received")
        // Array to capture OHLC candlestick data
        var candles: [OHLCData] = []
        
        viewModel.ohlcData
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { data in
                candles = data
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        viewModel.fetchChartData(for: "24h")
        wait(for: [exp], timeout: 2.0)
        
        // Then
        // Verify OHLC data was automatically fetched and contains expected candles
        XCTAssertEqual(candles.count, 5)
    }
    
    func testSetChartType_whenCandlestick_usesCachedOHLCIfAvailable() {
        // Given: Seed cached OHLC for btc 24h -> days "1"
        // Pre-populate cache with OHLC data to test cache usage for chart type switching
        let cached = TestDataFactory.createMockOHLCData(candles: 3)
        CacheService.shared.storeOHLCData(cached, for: "btc", currency: "usd", days: "1")
        // Create expectation for cached OHLC retrieval
        let exp = expectation(description: "ohlc from cache")
        // Array to capture OHLC data from cache
        var candles: [OHLCData] = []
        
        viewModel.ohlcData
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { data in
                candles = data
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        // Switch to candlestick chart type (should use cached OHLC data)
        viewModel.setChartType(.candlestick)
        wait(for: [exp], timeout: 1.5)
        
        // Then
        // Verify cached OHLC data was used for candlestick chart
        XCTAssertEqual(candles.count, 3)
    }
    
    // MARK: - Price Change Indicator
    
    func testPriceChangeIndicator_whenSharedPriceUpdates_emitsIndicator() {
        // Given
        // Test that price change indicators are published when shared data updates
        let exp = expectation(description: "price change indicator")
        // Flag to prevent multiple fulfillments of the expectation
        var fulfilled = false
        
        viewModel.priceChange
            .sink { indicator in
                if indicator != nil && !fulfilled {
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: update shared with new price for BTC
        // Create an updated version of the base coin with a higher price
        var updated = [baseCoin!]
        if var coin = updated.first,
           let old = coin.quote?["USD"] {
            // Create a new quote with a price increase of $100
            let newQuote = Quote(
                price: (old.price ?? 0) + 100.0,
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
            coin.quote?["USD"] = newQuote
            updated[0] = coin
        }
        // Update shared data manager with the new coin data
        mockShared.setMockCoins(updated)
        
        // Then
        wait(for: [exp], timeout: 2.0)
    }
    
    // MARK: - Smart Auto-Refresh
    
    func testSmartAutoRefresh_whenNoCacheAndNoCooldown_fetchesChartData() {
        // Given (no cache due to setUp)
        // Test that smart auto-refresh triggers when there's no cached data
        mockCoinManager.shouldSucceed = true
        // Provide fresh chart data for the auto-refresh
        mockCoinManager.mockChartData = [10, 11, 12]
        // Create expectation for auto-refresh completion
        let exp = expectation(description: "auto refresh chart")
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        
        // When
        // Trigger smart auto-refresh which should fetch data since cache is empty
        viewModel.smartAutoRefresh(for: "24h")
        wait(for: [exp], timeout: 3.0)
    }
    
    // MARK: - Retry
    
    func testRetryChartData_callsFetchForCurrentRange() {
        // Given
        // Test that retry mechanism properly re-attempts chart data fetch
        mockCoinManager.shouldSucceed = true
        // Provide chart data for the retry attempt
        mockCoinManager.mockChartData = [9, 8, 7]
        // Create expectation for retry completion
        let exp = expectation(description: "retry chart")
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        
        // When
        // Trigger retry mechanism (typically called after an error)
        viewModel.retryChartData()
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - Additional Coverage

    func testMapRangeToDays_returnsExpectedDayStrings() {
        XCTAssertEqual(viewModel.mapRangeToDays("24h"), "1")
        XCTAssertEqual(viewModel.mapRangeToDays("7d"), "7")
        XCTAssertEqual(viewModel.mapRangeToDays("30d"), "30")
        XCTAssertEqual(viewModel.mapRangeToDays("1y"), "365")
        XCTAssertEqual(viewModel.mapRangeToDays("365d"), "365")
        XCTAssertEqual(viewModel.mapRangeToDays("All"), "365")
        XCTAssertEqual(viewModel.mapRangeToDays("unknown"), "7")
    }

    func testSetChartType_whenLine_usesCachedChartDataAndClearsError() {
        // Given: seed cache for 7d => days "7"
        let cached = [3.0, 2.0, 1.0]
        CacheService.shared.storeChartData(cached, for: "btc", currency: "usd", days: "7")

        let dataExp = expectation(description: "line chart points from cache")
        var received: [Double] = []
        var errorMessages: [String?] = []

        viewModel.errorMessage
            .sink { errorMessages.append($0) }
            .store(in: &cancellables)

        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { points in
                received = points
                dataExp.fulfill()
            }
            .store(in: &cancellables)

        // When: switch to line for 7d
        viewModel.setChartType(.line, for: "7d")
        wait(for: [dataExp], timeout: 2.0)

        // Then
        XCTAssertFalse(received.isEmpty)
        // Should have cleared any error message on success path
        XCTAssertTrue(errorMessages.contains(nil))
    }

    func testSetSmoothingEnabled_persistsFlag_andRefetchesUsingCache() {
        // Given: clean defaults and seed 24h (1 day) cache
        UserDefaults.standard.removeObject(forKey: "ChartSmoothingEnabled")
        CacheService.shared.storeChartData([1.0, 2.0, 3.0], for: "btc", currency: "usd", days: "1")

        let exp = expectation(description: "chart points after smoothing toggle")
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        // When
        viewModel.setSmoothingEnabled(false)
        wait(for: [exp], timeout: 2.0)

        // Then: persisted and a fetch happened (points emitted)
        XCTAssertEqual(UserDefaults.standard.bool(forKey: "ChartSmoothingEnabled"), false)
    }

    func testCancelAllRequests_resetsLoadingStates() {
        // Given (no cache so a fetch will set loading)
        mockCoinManager.shouldSucceed = false

        let loadingExp = expectation(description: "loading toggled on")
        var sawLoadingTrue = false
        viewModel.isLoading
            .sink { isLoading in
                if isLoading { sawLoadingTrue = true; loadingExp.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.fetchChartData(for: "24h")
        wait(for: [loadingExp], timeout: 2.0)

        // When: cancel all
        let resetExp = expectation(description: "loading reset and stats loading cleared")
        var finalLoading = true
        var finalStatsLoading: Set<String> = ["24h"]
        var fulfilled = false

        func tryFulfill() {
            if !fulfilled && finalStatsLoading.isEmpty && finalLoading == false {
                fulfilled = true
                resetExp.fulfill()
            }
        }

        viewModel.isLoading
            .dropFirst()
            .sink { isLoading in
                finalLoading = isLoading
                tryFulfill()
            }
            .store(in: &cancellables)

        viewModel.statsLoadingState
            .dropFirst()
            .sink { state in
                finalStatsLoading = state
                tryFulfill()
            }
            .store(in: &cancellables)

        viewModel.cancelAllRequests()
        wait(for: [resetExp], timeout: 2.0)

        // Then
        XCTAssertTrue(sawLoadingTrue)
        XCTAssertFalse(finalLoading)
        XCTAssertTrue(finalStatsLoading.isEmpty)
    }

    func testChartLoadingState_whenDataExists_remainsLoadedEvenIfLaterError() {
        // Given: seed 24h cache so we have data
        CacheService.shared.storeChartData([5.0, 6.0], for: "btc", currency: "usd", days: "1")
        let dataExp = expectation(description: "initial data loaded")
        viewModel.chartLoadingState
            .dropFirst() // First state might be .empty
            .sink { state in
                if case .loaded = state { dataExp.fulfill() }
            }
            .store(in: &cancellables)
        viewModel.fetchChartData(for: "24h")
        wait(for: [dataExp], timeout: 2.0)

        // When: induce an error on a subsequent fetch (different range, no cache)
        mockCoinManager.shouldSucceed = false
        let stateExp = expectation(description: "state remains loaded despite error")
        var observedLoaded = false
        viewModel.chartLoadingState
            .sink { state in
                if case .loaded = state { observedLoaded = true; stateExp.fulfill() }
            }
            .store(in: &cancellables)
        viewModel.fetchChartData(for: "7d")
        wait(for: [stateExp], timeout: 3.0)

        // Then
        XCTAssertTrue(observedLoaded)
    }

    func testCurrentStats_containsCoreItemsIncludingMaxSupply() {
        // Given: using base coin from factory with rich quote
        // When
        let stats = viewModel.currentStats

        // Then: Should include core items
        let titles = Set(stats.map { $0.title })
        XCTAssertTrue(titles.contains("Market Cap"))
        XCTAssertTrue(titles.contains("Volume (24h)"))
        XCTAssertTrue(titles.contains("Market Dominance"))
        XCTAssertTrue(titles.contains("Circulating Supply"))
        XCTAssertTrue(titles.contains("Total Supply"))
        XCTAssertTrue(titles.contains("Market Pairs"))
        XCTAssertTrue(titles.contains("Rank"))
        XCTAssertTrue(titles.contains("Max Supply"))
    }

    func testUpdateStatsRange_whenOHLCDataAvailable_emitsHighLowItem() {
        // Given: provide OHLC cache for 7d so stats range switch consumes cache quickly
        let ohlc = TestDataFactory.createMockOHLCData(candles: 4)
        CacheService.shared.storeOHLCData(ohlc, for: "btc", currency: "usd", days: "7")

        let exp = expectation(description: "stats emit with high/low item")
        var receivedStats: [StatItem] = []

        viewModel.stats
            .filter { items in items.contains(where: { $0.title == "Low / High" }) }
            .prefix(1)
            .sink { items in
                receivedStats = items
                exp.fulfill()
            }
            .store(in: &cancellables)

        // When
        viewModel.updateStatsRange("7d")
        wait(for: [exp], timeout: 2.0)

        // Then: should include Low / High when data exists
        XCTAssertTrue(receivedStats.contains(where: { $0.title == "Low / High" }))
    }

    func testHighLowCalculation_includesLivePriceWithinBounds() {
        // Given: seed OHLC for 24h where highs are below current live price
        let lowHighBelowLive = (0..<6).map { _ in
            OHLCData(timestamp: Date(), open: 47000, high: 48000, low: 46000, close: 47000)
        }
        CacheService.shared.storeOHLCData(lowHighBelowLive, for: "btc", currency: "usd", days: "1")

        // Recreate VM to consume cached stats OHLC at init
        viewModel.cancelAllRequests()
        viewModel = CoinDetailsVM(
            coin: baseCoin,
            coinManager: mockCoinManager,
            sharedCoinDataManager: mockShared,
            requestManager: mockRequest
        )

        // When
        let stats = viewModel.currentStats
        let highLow = stats.first(where: { $0.title == "Low / High" })

        // Then: high should be at least current live price (50000 from factory)
        XCTAssertNotNil(highLow)
        XCTAssertEqual(highLow?.highLowPayload?.high, baseCoin.quote?["USD"]?.price)
    }
}
