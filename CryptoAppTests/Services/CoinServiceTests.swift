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
    
    func testFetchTopCoinsUsesCacheWhenAvailable() {
        // Given
        // Configure mock cache to return cached data instead of hitting network
        mockCache.shouldReturnCachedData = true
        // Create 4 fake coins and store them in the mock cache
        // This simulates a cache hit scenario
        let coins = TestDataFactory.createMockCoins(count: 4)
        mockCache.mockCoins = coins
        // Create expectation to wait for async operation to complete
        let exp = expectation(description: "coins from cache")
        // Array to capture what the service returns
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
        // Verify that we received the exact number of cached coins
        // This confirms the cache path was used successfully
        XCTAssertEqual(received.count, 4)
    }
    
    func testFetchTopCoinsFetchesAndCachesOnMiss() {
        // Given
        // Simulates a Cache miss
        XCTAssertTrue(mockCache.mockCoins.isEmpty)
        // Create 3 fake coin objects using data factory
        // Assigns them to mockRequest
        // When the service tries to fetch data, the request layer will return these 3 fake coins.
        let coins = TestDataFactory.createMockCoins(count: 3)
        mockRequest.mockCoins = coins
        // Create an XCTest expectation, which allows waiting for async Combine publishers.
        let exp = expectation(description: "coins fetched and cached")
        // Prepare an empty array 'received' to store what comes back from the service.
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
        // Verify that the 3 coins are stored in cache after being fetched
        XCTAssertEqual(mockCache.mockCoins.count, 3)
    }
    
    // MARK: - Logos (partial cache merge)
    
    func testFetchCoinLogos_whenAllRequestedIdsCached_returnsCachedLogosOnly() {
        // Given
        // Configure cache to return stored data
        mockCache.shouldReturnCachedData = true
        // Pre-populate cache with logos for coins 1 and 2
        // This simulates all requested logos being already cached
        mockCache.mockLogos = [1: "logo1", 2: "logo2"]
        // Create expectation for async operation
        let exp = expectation(description: "logos from cache only")
        // Dictionary to capture returned logo mappings
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
        // Verify we got back exactly 2 logos (no network request was made)
        XCTAssertEqual(received.count, 2)
        // Verify the cached logo URLs were returned correctly
        XCTAssertEqual(received[1], "logo1")
        XCTAssertEqual(received[2], "logo2")
    }
    
    func testFetchCoinLogos_whenPartiallyCached_fetchesMissingMergesAndCaches() {
        // Given: Partial cache scenario - ID 1 cached, ID 2 missing
        // Configure cache to return cached data when available
        mockCache.shouldReturnCachedData = true
        // Only coin ID 1 has a cached logo
        mockCache.mockLogos = [1: "cached_logo_1"]
        // Configure request manager to return logo for missing ID 2
        // This simulates fetching the missing logo from network
        mockRequest.mockLogos = [2: "fetched_logo_2"]
        // Create expectation for the merge operation
        let exp = expectation(description: "logos merged and cached")
        // Dictionary to capture the merged results
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
        // Verify we got both logos - one from cache, one from network
        XCTAssertEqual(received.count, 2)
        // Verify the cached logo was preserved
        XCTAssertEqual(received[1], "cached_logo_1")
        // Verify the fetched logo was included
        XCTAssertEqual(received[2], "fetched_logo_2")
        // Cache should now contain both logos for future requests
        XCTAssertEqual(mockCache.mockLogos.count, 2)
    }
    
    // MARK: - Quotes
    
    func testFetchQuotes_onCacheMiss_fetchesThenCaches() {
        // Given
        // Force a cache miss to test the fetch-and-cache path
        mockCache.shouldReturnCachedData = false
        // Define coin IDs we want to fetch quotes for
        let ids = [101, 202]
        // Create mock quote data that the request manager will return
        // Only providing quote for ID 101 to test partial responses
        let q: [Int: Quote] = [
            101: Quote(price: 1, volume24h: 0, volumeChange24h: 0, percentChange1h: 0, percentChange24h: 0, percentChange7d: 0, percentChange30d: 0, percentChange60d: nil, percentChange90d: nil, marketCap: 0, marketCapDominance: 0, fullyDilutedMarketCap: 0, lastUpdated: "")
        ]
        // Configure request manager to return our mock quotes
        mockRequest.mockQuotes = q
        // Create expectation for async fetch operation
        let exp = expectation(description: "quotes fetched and cached")
        // Dictionary to capture returned quotes
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
        // Verify the fetched quote data is correct
        XCTAssertEqual(received[101]?.price, 1)
        // Cache should have been updated with the fetched data
        // This ensures subsequent requests can use cached data
        XCTAssertEqual(mockCache.mockQuotes[101]?.price, 1)
    }
    
    // MARK: - CoinGecko Chart/OHLC
    
    func testFetchCoinGeckoChartData_onSuccess_cachesResult() {
        // Given
        // Force network fetch by disabling cache returns
        mockCache.shouldReturnCachedData = false
        // Verify cache starts empty to ensure we're testing the fetch path
        XCTAssertTrue(mockCache.mockChartData.isEmpty)
        // Configure request manager with mock chart data points
        mockRequest.mockChartData = [10, 20, 30]
        // Create expectation for chart data fetch
        let exp = expectation(description: "chart fetched and cached")
        // Array to capture returned chart data
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
        // Verify the service returned the correct chart data
        XCTAssertEqual(received, [10,20,30])
        // Verify the data was cached for future requests
        XCTAssertEqual(mockCache.mockChartData, [10,20,30])
    }
    
    func testFetchCoinGeckoOHLCData_onSuccess_cachesResult() {
        // Given
        // Force network fetch by bypassing cache
        mockCache.shouldReturnCachedData = false
        // Verify OHLC cache starts empty
        XCTAssertTrue(mockCache.mockOHLCData.isEmpty)
        // Create mock OHLC candlestick data (3 candles)
        let ohlc = TestDataFactory.createMockOHLCData(candles: 3)
        // Configure request manager to return our mock OHLC data
        mockRequest.mockOHLCData = ohlc
        // Create expectation for OHLC data fetch
        let exp = expectation(description: "ohlc fetched and cached")
        // Array to capture returned OHLC data
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
        // Verify we received the correct number of OHLC candles
        XCTAssertEqual(received.count, 3)
        // Verify the OHLC data was cached for future requests
        XCTAssertEqual(mockCache.mockOHLCData.count, 3)
    }
    
    // MARK: - Negative paths (error propagation)
    
    func testFetchTopCoins_onFailure_propagatesNetworkError() {
        // Given
        // Disable cache to force network request path
        mockCache.shouldReturnCachedData = false
        // Configure request manager to simulate a network failure
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        // Create expectation for error propagation
        let exp = expectation(description: "top coins failure propagated")
        // Variable to capture the error that gets propagated
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
        // Verify the network error was properly propagated to the caller
        // This ensures error handling works throughout the service layer
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchQuotes_onFailure_propagatesNetworkError() {
        // Given
        // Force network path by disabling cache
        mockCache.shouldReturnCachedData = false
        // Configure request manager to fail with network error
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        // Create expectation for error handling
        let exp = expectation(description: "quotes failure propagated")
        // Variable to capture propagated error
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
        // Verify quotes service properly propagates network errors
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinGeckoChartData_onFailure_propagatesNetworkError() {
        // Given
        // Bypass cache to test network error path
        mockCache.shouldReturnCachedData = false
        // Simulate chart data fetch failure
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        // Create expectation for error propagation
        let exp = expectation(description: "chart failure propagated")
        // Variable to capture the propagated error
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
        // Verify chart data service properly handles and propagates errors
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinGeckoOHLCData_onFailure_propagatesNetworkError() {
        // Given
        // Force network request by disabling cache
        mockCache.shouldReturnCachedData = false
        // Configure OHLC fetch to fail with network error
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        // Create expectation for error handling
        let exp = expectation(description: "ohlc failure propagated")
        // Variable to capture the error
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
        // Verify OHLC service properly propagates network errors
        XCTAssertEqual(receivedError, .invalidResponse)
    }
    
    func testFetchCoinLogos_whenNetworkFails_returnsOnlyCachedSubset() {
        // Given: Graceful degradation scenario - one cached, one missing
        // When network fails, should return cached subset only
        // Enable cache returns for the available logo
        mockCache.shouldReturnCachedData = true
        // Only coin ID 1 has a cached logo
        mockCache.mockLogos = [1: "cached_logo_1"]
        // Configure network request to fail when trying to fetch missing logo
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse
        // Create expectation for graceful error handling
        let exp = expectation(description: "logos returns cached subset on error")
        // Dictionary to capture partial results
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
        // Verify only the cached logo was returned (graceful degradation)
        XCTAssertEqual(received.count, 1)
        // Verify the cached logo is correct
        XCTAssertEqual(received[1], "cached_logo_1")
        // Verify the missing logo was not included (failed to fetch)
        XCTAssertNil(received[2])
    }
}

// MARK: - Additional cache-first and merge behavior tests (readable naming)
extension CoinServiceTests {
    func testChartDataUsesCacheWhenAvailableEvenIfNetworkFails() {
        // Given: chart data is cached
        mockCache.shouldReturnCachedData = true
        mockCache.mockChartData = [1, 2, 3]
        // Simulate network failure to ensure cache path short-circuits network
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse

        let exp = expectation(description: "chart data from cache")
        var received: [Double] = []

        // When
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { XCTFail("Should not fail when cache is available: \(err)") }
            }, receiveValue: { data in
                received = data
                exp.fulfill()
            })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received, [1,2,3])
    }

    func testOHLCDataUsesCacheWhenAvailableEvenIfNetworkFails() {
        // Given: OHLC data is cached
        mockCache.shouldReturnCachedData = true
        mockCache.mockOHLCData = TestDataFactory.createMockOHLCData(candles: 2)
        // Simulate network failure
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse

        let exp = expectation(description: "ohlc from cache")
        var receivedCount = 0

        // When
        service.fetchCoinGeckoOHLCData(for: "bitcoin", currency: "usd", days: "1")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { XCTFail("Should not fail when cache is available: \(err)") }
            }, receiveValue: { data in
                receivedCount = data.count
                exp.fulfill()
            })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedCount, 2)
    }

    func testFetchCoinLogosSecondCallUsesMergedCacheWithoutNetwork() {
        // Given: first call fetches missing logos and caches merged result
        mockCache.shouldReturnCachedData = true
        mockCache.mockLogos = [1: "cached_1"] // partially cached
        mockRequest.shouldSucceed = true
        mockRequest.mockLogos = [2: "fetched_2"] // network provides missing

        let first = expectation(description: "first merge")
        service.fetchCoinLogos(forIDs: [1,2])
            .sink { _ in first.fulfill() }
            .store(in: &cancellables)
        wait(for: [first], timeout: 1.0)

        // Now cache should contain both 1 and 2
        XCTAssertEqual(mockCache.mockLogos.count, 2)

        // When: simulate network failure; second call should return fully from cache
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse

        let second = expectation(description: "second uses cache only")
        var received: [Int:String] = [:]
        service.fetchCoinLogos(forIDs: [1,2])
            .sink { logos in
                received = logos
                second.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [second], timeout: 1.0)
        XCTAssertEqual(received[1], "cached_1")
        XCTAssertEqual(received[2], "fetched_2")
    }

    func testChartDataCachesAfterFetchThenNextCallIsCacheHit() {
        // Given: start with cache miss
        mockCache.shouldReturnCachedData = false
        mockCache.mockChartData = []
        mockRequest.shouldSucceed = true
        mockRequest.mockChartData = [7, 8, 9]

        let first = expectation(description: "first fetch caches")
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7")
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in first.fulfill() })
            .store(in: &cancellables)
        wait(for: [first], timeout: 1.0)

        // Ensure cached
        XCTAssertEqual(mockCache.mockChartData, [7,8,9])

        // When: force cache path and fail network
        mockCache.shouldReturnCachedData = true
        mockRequest.shouldSucceed = false

        let second = expectation(description: "second uses cache")
        var received: [Double] = []
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { XCTFail("Should use cache on second: \(err)") }
            }, receiveValue: { data in
                received = data
                second.fulfill()
            })
            .store(in: &cancellables)

        wait(for: [second], timeout: 1.0)
        XCTAssertEqual(received, [7,8,9])
    }

    func testTopCoinsMapsNonNetworkErrorToUnknown() {
        // Given: network path with generic NSError
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NSError(domain: "Test", code: -123)

        let exp = expectation(description: "top coins unknown error mapping")
        var receivedError: NetworkError?

        // When
        service.fetchTopCoins(limit: 2, convert: "USD", start: 1)
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
            }, receiveValue: { _ in XCTFail("Should not succeed") })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        if case .unknown = receivedError { } else { XCTFail("Expected .unknown mapping") }
    }

    func testQuotesMapsNonNetworkErrorToUnknown() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NSError(domain: "Test", code: -1)

        let exp = expectation(description: "quotes unknown error mapping")
        var receivedError: NetworkError?

        // When
        service.fetchQuotes(for: [1,2], convert: "USD")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
            }, receiveValue: { _ in XCTFail("Should not succeed") })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        if case .unknown = receivedError { } else { XCTFail("Expected .unknown mapping") }
    }

    func testChartMapsNonNetworkErrorToUnknown() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NSError(domain: "Test", code: -2)

        let exp = expectation(description: "chart unknown error mapping")
        var receivedError: NetworkError?

        // When
        service.fetchCoinGeckoChartData(for: "bitcoin", currency: "usd", days: "7")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
            }, receiveValue: { _ in XCTFail("Should not succeed") })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        if case .unknown = receivedError { } else { XCTFail("Expected .unknown mapping") }
    }

    func testOHLCMapsNonNetworkErrorToUnknown() {
        // Given
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NSError(domain: "Test", code: -3)

        let exp = expectation(description: "ohlc unknown error mapping")
        var receivedError: NetworkError?

        // When
        service.fetchCoinGeckoOHLCData(for: "bitcoin", currency: "usd", days: "7")
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { receivedError = err; exp.fulfill() }
            }, receiveValue: { _ in XCTFail("Should not succeed") })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        if case .unknown = receivedError { } else { XCTFail("Expected .unknown mapping") }
    }

    func testFetchCoinLogosErrorWithNoCacheReturnsEmpty() {
        // Given: no cache available, network fails
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse

        let exp = expectation(description: "logos empty on error without cache")
        var received: [Int:String] = [ : ]

        // When
        service.fetchCoinLogos(forIDs: [42])
            .sink { logos in
                received = logos
                exp.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(received.isEmpty)
    }

    func testFetchCoinLogosReturnsOnlyRequestedIdsFromCache() {
        // Given: cache has more logos than requested
        mockCache.shouldReturnCachedData = true
        mockCache.mockLogos = [1: "a", 2: "b", 3: "c"]

        let exp = expectation(description: "logos only requested ids")
        var received: [Int:String] = [:]

        // When: request subset [1,3]
        service.fetchCoinLogos(forIDs: [1,3])
            .sink { logos in
                received = logos
                exp.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[1], "a")
        XCTAssertEqual(received[3], "c")
        XCTAssertNil(received[2])
    }

    func testFetchTopCoinsCacheHitShortCircuitsWhenNetworkFails() {
        // Given: cache has coins
        mockCache.shouldReturnCachedData = true
        mockCache.mockCoins = TestDataFactory.createMockCoins(count: 2)
        // And simulate network failure
        mockRequest.shouldSucceed = false
        mockRequest.mockError = NetworkError.invalidResponse

        let exp = expectation(description: "top coins from cache on failure")
        var receivedCount = 0

        // When
        service.fetchTopCoins(limit: 2, convert: "USD", start: 1)
            .sink(receiveCompletion: { completion in
                if case .failure(let err) = completion { XCTFail("Should not fail when cache exists: \(err)") }
            }, receiveValue: { list in
                receivedCount = list.count
                exp.fulfill()
            })
            .store(in: &cancellables)

        // Then
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(receivedCount, 2)
    }
}

