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
    
    func testFetchChartDataSuccess() {
        // Given
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockChartData = [100.0, 101.5, 102.3]
        let exp = expectation(description: "chart points received")
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
        XCTAssertFalse(received.isEmpty)
    }
    
    func testFetchChartDataErrorPublishesErrorState() {
        // Given (no cache due to setUp)
        mockCoinManager.shouldSucceed = false
        let exp = expectation(description: "error state published")
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
        viewModel.fetchChartData(for: "24h")
        wait(for: [exp], timeout: 3.0)
        
        // Then
        XCTAssertTrue(gotError)
    }
    
    func testChartDataUsesCachePathWithoutLoading() {
        // Given: Seed cache for btc 24h -> days "1"
        CacheService.shared.storeChartData([200.0, 201.0], for: "btc", currency: "usd", days: "1")
        let exp = expectation(description: "cached chart used")
        var received: [Double] = []
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
        XCTAssertEqual(received.first, 200.0)
        XCTAssertFalse(loadingStates.contains(true))
    }
    
    // MARK: - OHLC Data
    
    func testOHLCDataFetchTriggeredAfterChart() {
        // Given
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockChartData = [1, 2, 3]
        mockCoinManager.mockOHLCData = TestDataFactory.createMockOHLCData(candles: 5)
        let exp = expectation(description: "ohlc received")
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
        XCTAssertEqual(candles.count, 5)
    }
    
    func testSetChartTypeCandlestickUsesCachedOHLC() {
        // Given: Seed cached OHLC for btc 24h -> days "1"
        let cached = TestDataFactory.createMockOHLCData(candles: 3)
        CacheService.shared.storeOHLCData(cached, for: "btc", currency: "usd", days: "1")
        let exp = expectation(description: "ohlc from cache")
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
        viewModel.setChartType(.candlestick)
        wait(for: [exp], timeout: 1.5)
        
        // Then
        XCTAssertEqual(candles.count, 3)
    }
    
    // MARK: - Price Change Indicator
    
    func testPriceChangeIndicatorPublishedOnSharedUpdate() {
        // Given
        let exp = expectation(description: "price change indicator")
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
        var updated = [baseCoin!]
        if var coin = updated.first,
           let old = coin.quote?["USD"] {
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
        mockShared.setMockCoins(updated)
        
        // Then
        wait(for: [exp], timeout: 2.0)
    }
    
    // MARK: - Smart Auto-Refresh
    
    func testSmartAutoRefreshFetchesWhenNoCacheAndNoCooldown() {
        // Given (no cache due to setUp)
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockChartData = [10, 11, 12]
        let exp = expectation(description: "auto refresh chart")
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        
        // When
        viewModel.smartAutoRefresh(for: "24h")
        wait(for: [exp], timeout: 3.0)
    }
    
    // MARK: - Retry
    
    func testRetryChartDataCallsFetch() {
        // Given
        mockCoinManager.shouldSucceed = true
        mockCoinManager.mockChartData = [9, 8, 7]
        let exp = expectation(description: "retry chart")
        
        viewModel.chartPoints
            .filter { !$0.isEmpty }
            .prefix(1)
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)
        
        // When
        viewModel.retryChartData()
        wait(for: [exp], timeout: 2.0)
    }
}
