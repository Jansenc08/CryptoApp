//
//  CacheServiceTests.swift
//  CryptoAppTests
//
//  Documentation:
//  Unit tests for CacheService focusing on TTL expiry, type-specific getters/setters,
//  image caching, removal/clearing, and basic stats.
//

import XCTest
import UIKit
@testable import CryptoApp

final class CacheServiceTests: XCTestCase {
    
    private var cache: CacheService!
    
    override func setUp() {
        super.setUp()
        cache = CacheService() // Fresh instance to avoid singleton state
    }
    
    override func tearDown() {
        cache.clear()
        cache = nil
        super.tearDown()
    }
    
    private func wait(_ seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 0.5)
    }
    
    // MARK: - TTL
    
    func testSetGetRespectsTTLExpiry() {
        // Given
        // Store a value with a very short TTL
        let key = "test_short_ttl"
        cache.set(key: key, value: "value", ttl: 0.05)
        
        // When
        // Immediately fetch should return the value
        let immediate: String? = cache.get(key: key, type: String.self)
        // After TTL, fetch should return nil (expired)
        wait(0.1)
        let afterTTL: String? = cache.get(key: key, type: String.self)
        
        // Then
        XCTAssertEqual(immediate, "value")
        XCTAssertNil(afterTTL)
    }
    
    // MARK: - Type-Specific Getters/Setters
    
    func testStoreAndGetCoinList() {
        // Given
        let coins = TestDataFactory.createMockCoins(count: 3)
        
        // When
        cache.storeCoinList(coins, limit: 3, start: 1, convert: "USD", sortType: "market_cap", sortDir: "desc")
        let fetched = cache.getCoinList(limit: 3, start: 1, convert: "USD", sortType: "market_cap", sortDir: "desc")
        
        // Then
        XCTAssertEqual(fetched?.count, 3)
    }
    
    func testStoreAndGetQuotes() {
        // Given
        let quotes: [Int: Quote] = [1: Quote(price: 1, volume24h: 0, volumeChange24h: 0, percentChange1h: 0, percentChange24h: 0, percentChange7d: 0, percentChange30d: 0, percentChange60d: nil, percentChange90d: nil, marketCap: 0, marketCapDominance: 0, fullyDilutedMarketCap: 0, lastUpdated: "")]
        let ids = [1]
        
        // When
        cache.storeQuotes(quotes, for: ids, convert: "USD")
        let fetched = cache.getQuotes(for: ids, convert: "USD")
        
        // Then
        XCTAssertEqual(fetched?[1]?.price, 1)
    }
    
    func testStoreAndGetChartAndOHLC() {
        // Given
        let coinId = "btc"
        
        // When
        cache.storeChartData([1,2,3], for: coinId, currency: "usd", days: "7")
        cache.storeOHLCData(TestDataFactory.createMockOHLCData(candles: 2), for: coinId, currency: "usd", days: "1")
        let chart = cache.getChartData(for: coinId, currency: "usd", days: "7")
        let ohlc = cache.getOHLCData(for: coinId, currency: "usd", days: "1")
        
        // Then
        XCTAssertEqual(chart, [1,2,3])
        XCTAssertEqual(ohlc?.count, 2)
    }
    
    // MARK: - Image Caching
    
    func testImageCachingStoreAndGet() {
        // Given
        let url = "https://example.com/img.png"
        UIGraphicsBeginImageContext(CGSize(width: 2, height: 2))
        UIColor.red.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 2, height: 2))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // When
        cache.storeCachedImage(image, for: url)
        let fetched = cache.getCachedImage(for: url)
        
        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.size.width, 2)
        XCTAssertEqual(fetched?.size.height, 2)
    }
    
    // MARK: - Remove / Clear / Stats
    
    func testRemoveKeyAndClearEmptiesCache() {
        // Given
        cache.set(key: "k1", value: 10, ttl: 60)
        cache.set(key: "k2", value: 20, ttl: 60)
        
        // When: remove one key
        cache.remove(key: "k1")
        let v1: Int? = cache.get(key: "k1", type: Int.self)
        let v2: Int? = cache.get(key: "k2", type: Int.self)
        
        // Then
        XCTAssertNil(v1)
        XCTAssertEqual(v2, 20)
        
        // When: clear all
        cache.clear()
        let v2After: Int? = cache.get(key: "k2", type: Int.self)
        
        // Then
        XCTAssertNil(v2After)
    }
    
    func testGetCacheStatsReturnsSaneValues() {
        // Given
        cache.set(key: "stats_test", value: [1,2,3], ttl: 60)
        
        // When
        let stats = cache.getCacheStats()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.count, 0)
        XCTAssertGreaterThanOrEqual(stats.maxMemory, stats.memoryUsage)
    }
}


