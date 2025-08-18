//
//  CoinManagerTests.swift
//  CryptoAppTests
//

import XCTest
import Combine
@testable import CryptoApp

final class CoinManagerTests: XCTestCase {
    
    private var coinManager: CoinManager!
    private var mockService: MockCoinService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockService = MockCoinService()
        coinManager = CoinManager(coinService: mockService)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.removeAll()
        coinManager = nil
        mockService = nil
        super.tearDown()
    }
    
    func testGetTopCoinsPassThrough() {
        // Given
        mockService.shouldSucceed = true
        let expected = TestDataFactory.createMockCoins(count: 3)
        mockService.mockCoins = expected
        let exp = expectation(description: "top coins fetched")
        var received: [Coin] = []
        
        // When
        coinManager.getTopCoins(limit: 3, convert: "USD", start: 1, sortType: "market_cap", sortDir: "desc", priority: .high)
            .sink(receiveCompletion: { _ in }, receiveValue: { coins in
                received = coins
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received.first?.id, expected.first?.id)
    }
    
    func testFetchChartDataRangeMapping() {
        // Given
        mockService.shouldSucceed = true
        mockService.mockChartData = [1,2,3]
        let exp = expectation(description: "chart data fetched")
        var received: [Double] = []
        
        // When (range "7" should map to days "7" internally)
        coinManager.fetchChartData(for: "btc", range: "7", currency: "usd", priority: .high)
            .sink(receiveCompletion: { _ in }, receiveValue: { data in
                received = data
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
    }
    
    func testFetchOHLCDataRangeMapping() {
        // Given
        mockService.shouldSucceed = true
        mockService.mockOHLCData = TestDataFactory.createMockOHLCData(candles: 2)
        let exp = expectation(description: "ohlc data fetched")
        var received: [OHLCData] = []
        
        // When (range "30" should map to days "30" internally)
        coinManager.fetchOHLCData(for: "btc", range: "30", currency: "usd", priority: .normal)
            .sink(receiveCompletion: { _ in }, receiveValue: { data in
                received = data
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 2)
    }
}
