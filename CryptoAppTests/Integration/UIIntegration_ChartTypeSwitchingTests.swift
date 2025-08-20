//
//  UIIntegration_ChartTypeSwitchingTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Integration-style VM test for CoinDetailsVM chart type switching.
//  Validates that:
//  - Switching to candlestick uses cached OHLC if available
//  - Switching to line uses cached chart points if available
//  No UIKit dependence; validations are performed by observing publishers.
//

import XCTest
import Combine
@testable import CryptoApp

final class UIIntegration_ChartTypeSwitchingTests: XCTestCase {
    
    private var vm: CoinDetailsVM!
    private var mockCoinManager: MockCoinManager!
    private var mockShared: MockSharedCoinDataManager!
    private var mockRequest: MockRequestManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        CacheService.shared.clearCache()
        mockCoinManager = MockCoinManager()
        mockShared = MockSharedCoinDataManager()
        mockRequest = MockRequestManager()
        cancellables = []
        let coin = TestDataFactory.createMockCoin(id: 1, symbol: "BTC", name: "Bitcoin", rank: 1)
        vm = CoinDetailsVM(coin: coin, coinManager: mockCoinManager, sharedCoinDataManager: mockShared, requestManager: mockRequest)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        vm = nil
        mockCoinManager = nil
        mockShared = nil
        mockRequest = nil
        super.tearDown()
    }
    
    func testSwitchLineToCandlestickUsesCacheIfAvailable() {
        // Given cached OHLC for 24h -> days "1"
        // Test that switching chart types uses cached data when available
        // Pre-populate cache with OHLC data for candlestick charts
        let ohlc = TestDataFactory.createMockOHLCData(candles: 4)
        CacheService.shared.storeOHLCData(ohlc, for: "btc", currency: "usd", days: "1")
        // Create expectation for cached data usage
        let exp = expectation(description: "candlestick shows cached ohlc")
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        vm.ohlcData
            .sink { data in
                if !data.isEmpty && !fulfilled {
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // User switches from line chart to candlestick chart
        vm.setChartType(.candlestick)
        wait(for: [exp], timeout: 2.0)
    }
    
    func testSwitchCandlestickToLineShowsChartPoints() {
        // Given chart data in cache for line
        // Test switching from candlestick back to line chart using cached data
        CacheService.shared.storeChartData([1,2,3,4,5], for: "btc", currency: "usd", days: "1")
        // Create expectation for cached line chart data
        let exp = expectation(description: "line shows cached points")
        // Flag to prevent multiple expectation fulfillments
        var fulfilled = false
        
        vm.chartPoints
            .sink { points in
                if !points.isEmpty && !fulfilled {
                    fulfilled = true
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        // User switches from candlestick back to line chart
        vm.setChartType(.line)
        wait(for: [exp], timeout: 2.0)
    }
}
