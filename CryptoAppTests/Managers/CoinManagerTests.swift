//
//  CoinManagerTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for CoinManager focusing on what it actually does:
//  - Forwards parameters and priorities to CoinService (pass-through layer)
//  - Translates chart/ohlc "range" strings into CoinGecko "days" values
//  Pattern:
//  - Uses an internal SpyCoinService to capture the last-call parameters
//    so we can assert exact values without depending on network or caches
//

import XCTest
import Combine
@testable import CryptoApp

final class CoinManagerParameterMappingTests: XCTestCase {
    
    private final class SpyCoinService: CoinServiceProtocol {
        // Captured parameters for the most recent calls.
        // Each is a tuple mirroring the service API so we can assert pass-through accuracy.
        var lastTopCoinsParams: (limit: Int, convert: String, start: Int, sortType: String, sortDir: String, priority: RequestPriority)?
        var lastLogosParams: (ids: [Int], priority: RequestPriority)?
        var lastQuotesParams: (ids: [Int], convert: String, priority: RequestPriority)?
        var lastChartParams: (id: String, currency: String, days: String, priority: RequestPriority)?
        var lastOHLCParams: (id: String, currency: String, days: String, priority: RequestPriority)?
        
        // MARK: - Spy implementations simply record inputs and return empty publishers
        func fetchTopCoins(limit: Int, convert: String, start: Int, sortType: String, sortDir: String, priority: RequestPriority) -> AnyPublisher<[Coin], NetworkError> {
            lastTopCoinsParams = (limit, convert, start, sortType, sortDir, priority)
            return Just([]).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        func fetchCoinLogos(forIDs ids: [Int], priority: RequestPriority) -> AnyPublisher<[Int : String], Never> {
            lastLogosParams = (ids, priority)
            return Just([:]).eraseToAnyPublisher()
        }
        func fetchQuotes(for ids: [Int], convert: String, priority: RequestPriority) -> AnyPublisher<[Int : Quote], NetworkError> {
            lastQuotesParams = (ids, convert, priority)
            return Just([:]).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        func fetchCoinGeckoChartData(for coinId: String, currency: String, days: String, priority: RequestPriority) -> AnyPublisher<[Double], NetworkError> {
            lastChartParams = (coinId, currency, days, priority)
            return Just([]).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
        func fetchCoinGeckoOHLCData(for coinId: String, currency: String, days: String, priority: RequestPriority) -> AnyPublisher<[OHLCData], NetworkError> {
            lastOHLCParams = (coinId, currency, days, priority)
            return Just([]).setFailureType(to: NetworkError.self).eraseToAnyPublisher()
        }
    }
    
    private var service: SpyCoinService!
    private var manager: CoinManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        service = SpyCoinService()
        manager = CoinManager(coinService: service)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.removeAll()
        manager = nil
        service = nil
        super.tearDown()
    }
    
    func testGetTopCoinsPassesParametersAndPriority() {
        // Given
        // Call with explicit, non-default values to verify pass-through
        let exp = expectation(description: "top coins")
        
        // When
        manager.getTopCoins(limit: 123, convert: "EUR", start: 5, sortType: "volume_24h", sortDir: "asc", priority: .high)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { _ in })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 1.0)
        
        // Then
        // Assert every parameter and priority was forwarded as provided
        let p = service.lastTopCoinsParams
        XCTAssertEqual(p?.limit, 123)
        XCTAssertEqual(p?.convert, "EUR")
        XCTAssertEqual(p?.start, 5)
        XCTAssertEqual(p?.sortType, "volume_24h")
        XCTAssertEqual(p?.sortDir, "asc")
        XCTAssertEqual(p?.priority, .high)
    }
    
    func testGetCoinLogosPassesIdsAndPriority() {
        // Given
        let ids = [1,2,3]
        
        // When
        _ = manager.getCoinLogos(forIDs: ids, priority: .low).sink(receiveValue: { _ in })
        
        // Then
        // IDs and priority should match the request
        XCTAssertEqual(service.lastLogosParams?.ids, ids)
        XCTAssertEqual(service.lastLogosParams?.priority, .low)
    }
    
    func testGetQuotesPassesIdsConvertAndPriority() {
        // Given
        let ids = [42]
        
        // When
        _ = manager.getQuotes(for: ids, convert: "USD", priority: .normal).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        
        // Then
        // Verify IDs, currency and priority pass-through
        XCTAssertEqual(service.lastQuotesParams?.ids, ids)
        XCTAssertEqual(service.lastQuotesParams?.convert, "USD")
        XCTAssertEqual(service.lastQuotesParams?.priority, .normal)
    }
    
    func testFetchChartDataMapsRangeToDays() {
        // Given
        // Map ranges to days per implementation: 1,7,30,365, default->1
        
        // When
        _ = manager.fetchChartData(for: "bitcoin", range: "1", currency: "usd", priority: .high).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = manager.fetchChartData(for: "bitcoin", range: "7", currency: "usd", priority: .high).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = manager.fetchChartData(for: "bitcoin", range: "30", currency: "usd", priority: .high).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = manager.fetchChartData(for: "bitcoin", range: "365", currency: "usd", priority: .high).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        _ = manager.fetchChartData(for: "bitcoin", range: "unknown", currency: "usd", priority: .high).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        
        // Then
        // Last call used an unknown range → default days should be "1"
        XCTAssertEqual(service.lastChartParams?.days, "1")
        XCTAssertEqual(service.lastChartParams?.priority, .high)
    }
    
    func testFetchOHLCDataMapsRangeToDays() {
        // Given/When
        _ = manager.fetchOHLCData(for: "bitcoin", range: "7", currency: "usd", priority: .normal).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        
        // Then
        // Verify days mapping and priority forwarding
        XCTAssertEqual(service.lastOHLCParams?.days, "7")
        XCTAssertEqual(service.lastOHLCParams?.priority, .normal)
    }
}
