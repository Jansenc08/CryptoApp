//
//  CoinServiceTests.swift
//  CryptoAppTests
//

import XCTest
import Combine
@testable import CryptoApp

// Documentation:
// Unit tests for CoinService focusing on cache-first behavior, partial cache merge (logos),
// request manager fetch paths, and cache writes after successful fetch.
// Uses MockCacheService and MockRequestManager to avoid real networking.

final class CoinServiceTests: XCTestCase {
    
    private var service: CoinService!
    private var mockCache: MockCacheService!
    private var mockRequest: MockRequestManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCache = MockCacheService()
        mockRequest = MockRequestManager()
        service = CoinService(cacheService: mockCache, requestManager: mockRequest)
        cancellables = []
        
        // Reset mock states
        mockCache.clearCache()
        // IMPORTANT: By default, make cache getters return nil so fetch paths are exercised.
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = true
        mockRequest.mockDelay = 0
    }
    
    override func tearDown() {
        cancellables.removeAll()
        service = nil
        mockCache = nil
        mockRequest = nil
        super.tearDown()
    }
    
    // MARK: - Top Coins
    
    func testFetchTopCoins_UsesCacheWhenAvailable() {
        // Given
        mockCache.shouldReturnCachedData = true
        let coins = TestDataFactory.createMockCoins(count: 4)
        mockCache.mockCoins = coins
        let exp = expectation(description: "coins from cache")
        var received: [Coin] = []
        
        // When
        service.fetchTopCoins(limit: 4, convert: "USD", start: 1)
            .sink(receiveCompletion: { _ in }, receiveValue: { list in
                received = list
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 4)
    }
    
    func testFetchTopCoins_FetchesAndCachesOnMiss() {
        // Given
        XCTAssertTrue(mockCache.mockCoins.isEmpty)
        let coins = TestDataFactory.createMockCoins(count: 3)
        mockRequest.mockCoins = coins
        let exp = expectation(description: "coins fetched and cached")
        var received: [Coin] = []
        
        // When
        service.fetchTopCoins(limit: 3, convert: "USD", start: 1)
            .sink(receiveCompletion: { _ in }, receiveValue: { list in
                received = list
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
        // storeCoinList writes into mockCache.mockCoins
        XCTAssertEqual(mockCache.mockCoins.count, 3)
    }
    
    // MARK: - Logos (partial cache merge)
    
    func testFetchCoinLogos_AllCachedShortCircuits() {
        // Given
        mockCache.shouldReturnCachedData = true
        mockCache.mockLogos = [1: "logo1", 2: "logo2"]
        let exp = expectation(description: "logos from cache only")
        var received: [Int: String] = [:]
        
        // When
        service.fetchCoinLogos(forIDs: [1, 2])
            .sink { logos in
                received = logos
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[1], "logo1")
        XCTAssertEqual(received[2], "logo2")
    }
    
    func testFetchCoinLogos_MergesMissingAndCachesMerged() {
        // Given: ID 1 cached, ID 2 missing
        mockCache.shouldReturnCachedData = true
        mockCache.mockLogos = [1: "cached_logo_1"]
        mockRequest.mockLogos = [2: "fetched_logo_2"]
        let exp = expectation(description: "logos merged and cached")
        var received: [Int: String] = [:]
        
        // When
        service.fetchCoinLogos(forIDs: [1, 2])
            .sink { logos in
                received = logos
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[1], "cached_logo_1")
        XCTAssertEqual(received[2], "fetched_logo_2")
        // Cache should now contain both
        XCTAssertEqual(mockCache.mockLogos.count, 2)
    }
    
    // MARK: - Quotes
    
    func testFetchQuotes_UsesCacheOrCachesOnFetch() {
        // Given
        mockCache.shouldReturnCachedData = false // force fetch
        let ids = [101, 202]
        let q: [Int: Quote] = [
            101: Quote(price: 1, volume24h: 0, volumeChange24h: 0, percentChange1h: 0, percentChange24h: 0, percentChange7d: 0, percentChange30d: 0, percentChange60d: nil, percentChange90d: nil, marketCap: 0, marketCapDominance: 0, fullyDilutedMarketCap: 0, lastUpdated: "")
        ]
        mockRequest.mockQuotes = q
        let exp = expectation(description: "quotes fetched and cached")
        var received: [Int: Quote] = [:]
        
        // When
        service.fetchQuotes(for: ids, convert: "USD")
            .sink(receiveCompletion: { _ in }, receiveValue: { quotes in
                received = quotes
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received[101]?.price, 1)
        // Cache should have been written
        XCTAssertEqual(mockCache.mockQuotes[101]?.price, 1)
    }
    
    // MARK: - CoinGecko Chart/OHLC
    
    func testFetchCoinGeckoChartData_CachesOnSuccess() {
        // Given
        mockCache.shouldReturnCachedData = false // force fetch
        XCTAssertTrue(mockCache.mockChartData.isEmpty)
        mockRequest.mockChartData = [10, 20, 30]
        let exp = expectation(description: "chart fetched and cached")
        var received: [Double] = []
        
        // When
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7", priority: .high)
            .sink(receiveCompletion: { _ in }, receiveValue: { data in
                received = data
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received, [10,20,30])
        XCTAssertEqual(mockCache.mockChartData, [10,20,30])
    }
    
    func testFetchCoinGeckoOHLCData_CachesOnSuccess() {
        // Given
        mockCache.shouldReturnCachedData = false // force fetch
        XCTAssertTrue(mockCache.mockOHLCData.isEmpty)
        let ohlc = TestDataFactory.createMockOHLCData(candles: 3)
        mockRequest.mockOHLCData = ohlc
        let exp = expectation(description: "ohlc fetched and cached")
        var received: [OHLCData] = []
        
        // When
        service.fetchCoinGeckoOHLCData(for: "bitcoin", currency: "usd", days: "7", priority: .normal)
            .sink(receiveCompletion: { _ in }, receiveValue: { data in
                received = data
                exp.fulfill()
            })
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(mockCache.mockOHLCData.count, 3)
    }
    
    // MARK: - Negative paths (error propagation)
    
    func testFetchTopCoins_PropagatesErrorOnFailure() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        let exp = expectation(description: "top coins failure propagated")
        var receivedError: NetworkError?
        
        // When
        service.fetchTopCoins(limit: 3, convert: "USD", start: 1)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
                },
                receiveValue: { _ in XCTFail("Should not succeed on error") }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchQuotes_PropagatesErrorOnFailure() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        let exp = expectation(description: "quotes failure propagated")
        var receivedError: NetworkError?
        
        // When
        service.fetchQuotes(for: [1,2], convert: "USD")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
                },
                receiveValue: { _ in XCTFail("Should not succeed on error") }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinGeckoChartData_PropagatesErrorOnFailure() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        let exp = expectation(description: "chart failure propagated")
        var receivedError: NetworkError?
        
        // When
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
                },
                receiveValue: { _ in XCTFail("Should not succeed on error") }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinGeckoOHLCData_PropagatesErrorOnFailure() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        let exp = expectation(description: "ohlc failure propagated")
        var receivedError: NetworkError?
        
        // When
        service.fetchCoinGeckoOHLCData(for: "bitcoin", currency: "usd", days: "7")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
                },
                receiveValue: { _ in XCTFail("Should not succeed on error") }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinLogos_ErrorReturnsCachedSubset() {
        // Given: one cached, one missing; request fails -> should return cached subset only
        mockCache.shouldReturnCachedData = true
        mockCache.mockLogos = [1: "cached_logo_1"]
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        let exp = expectation(description: "logos returns cached subset on error")
        var received: [Int: String] = [:]
        
        // When
        service.fetchCoinLogos(forIDs: [1, 2])
            .sink { logos in
                received = logos
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[1], "cached_logo_1")
        XCTAssertNil(received[2])
    }
}
