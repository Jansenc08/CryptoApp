//
//  CacheServiceTests.swift
//  CryptoAppTests
//

import XCTest
import UIKit
@testable import CryptoApp

final class CacheServiceTests: XCTestCase {

    private var cache: CacheService!

    override func setUp() {
        super.setUp()
        cache = CacheService()
        cache.clear()
    }

    override func tearDown() {
        cache.clear()
        cache = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func wait(seconds: TimeInterval) {
        let exp = expectation(description: "wait \(seconds)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }

    private func makeSolidImage(width: Int, height: Int, color: UIColor = .red) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - TTL Validation

    func testTTLExpirationRemovesEntry() {
        // Given
        let key = "ttl_test_\(UUID().uuidString)"
        let value = "hello"
        let shortTTL: TimeInterval = 0.2

        // When - store with short TTL
        cache.set(key: key, value: value, ttl: shortTTL)

        // Give async barrier write a moment to complete
        wait(seconds: 0.05)

        // Then - immediately available
        XCTAssertEqual(cache.get(key: key, type: String.self), value)

        // After TTL elapses, value should be gone and memory usage reduced
        wait(seconds: 0.3)

        // Trigger read which also trims expired entry and reduces memory usage
        XCTAssertNil(cache.get(key: key, type: String.self))

        // Memory usage should be zero after expiration cleanup
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    // MARK: - Memory Pressure Handling

    func testMemoryPressureClearsCacheWhenAboveThreshold() {
        // Given - Insert a large image to exceed half of the 100MB limit (~50MB)
        // 6000 x 2200 x 4 bytes ≈ 52.8MB
        let key = "memory_pressure_\(UUID().uuidString)"
        let largeImage = makeSolidImage(width: 6000, height: 2200)
        cache.set(key: key, value: largeImage, ttl: 60)

        // Allow write to complete and ensure present
        wait(seconds: 0.05)
        XCTAssertNotNil(cache.get(key: key, type: UIImage.self))

        // When - Simulate memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        // Give the async cleanup a brief moment
        wait(seconds: 0.1)

        // Then - Cache should be cleared
        XCTAssertNil(cache.get(key: key, type: UIImage.self))
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    // MARK: - Eviction Policies (NSCache totalCostLimit)

    func testEvictionWhenExceedingTotalCostLimit() {
        // Given - Add multiple moderately large entries to exceed ~100MB cost
        // 2048x2048 ~ 16MB each; 7 images ~ 112MB
        var keys: [String] = []
        for i in 0..<7 {
            let key = "evict_\(i)_\(UUID().uuidString)"
            keys.append(key)
            let img = makeSolidImage(width: 2048, height: 2048)
            cache.set(key: key, value: img, ttl: 60)
        }

        // Allow async writes
        wait(seconds: 0.2)

        // When - Fetch back
        let retrieved = keys.map { cache.get(key: $0, type: UIImage.self) }

        // Then - NSCache should have evicted at least one entry due to totalCostLimit
        let presentCount = retrieved.compactMap { $0 }.count
        XCTAssertLessThan(presentCount, keys.count, "At least one entry should be evicted when exceeding total cost limit")

        // Sanity: At least one entry should still be available
        XCTAssertGreaterThan(presentCount, 0, "Not all entries should be evicted")
    }

    // MARK: - Additional TTL Edge Cases

    func testZeroTTLExpiresImmediately() {
        let key = "ttl_zero_\(UUID().uuidString)"
        cache.set(key: key, value: 123, ttl: 0)
        wait(seconds: 0.02)
        XCTAssertNil(cache.get(key: key, type: Int.self))
    }

    func testLongTTLRemainsValid() {
        let key = "ttl_long_\(UUID().uuidString)"
        cache.set(key: key, value: ["a", "b"], ttl: 60)
        wait(seconds: 0.05)
        XCTAssertEqual(cache.get(key: key, type: [String].self)?.count, 2)
    }

    // MARK: - Clear Behavior

    func testClearEmptiesCacheAndResetsMemoryUsage() {
        let key = "clear_test_\(UUID().uuidString)"
        cache.set(key: key, value: makeSolidImage(width: 800, height: 800), ttl: 60)
        wait(seconds: 0.05)
        XCTAssertNotNil(cache.get(key: key, type: UIImage.self))

        cache.clear()
        // Allow barrier clear
        wait(seconds: 0.05)
        XCTAssertNil(cache.get(key: key, type: UIImage.self))
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    // MARK: - Memory Warning Below Threshold

    func testMemoryWarningDoesNotClearWhenBelowThreshold() {
        // Given usage well under 50MB
        let key = "below_threshold_\(UUID().uuidString)"
        let smallImage = makeSolidImage(width: 1000, height: 1000) // ~4MB
        cache.set(key: key, value: smallImage, ttl: 60)
        wait(seconds: 0.05)

        let statsBefore = cache.getCacheStats()
        XCTAssertLessThanOrEqual(statsBefore.memoryUsage, statsBefore.maxMemory / 2)

        // When - Simulate memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        wait(seconds: 0.1)

        // Then - Entry should remain
        XCTAssertNotNil(cache.get(key: key, type: UIImage.self))
    }

    // MARK: - Count Limit Eviction

    func testCountLimitEvictionOccurs() {
        // Insert more than 200 small entries
        let total = 250
        for i in 0..<total {
            cache.set(key: "count_key_\(i)", value: "v_\(i)", ttl: 60)
        }
        wait(seconds: 0.2)

        // Fetch how many remain
        var present = 0
        for i in 0..<total {
            if cache.get(key: "count_key_\(i)", type: String.self) != nil { present += 1 }
        }

        XCTAssertLessThan(present, total, "NSCache should evict some entries when countLimit is exceeded")
        XCTAssertGreaterThan(present, 0, "Some entries should remain after eviction")
    }

    // MARK: - Concurrency

    func testConcurrentSetAndGet() {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        let total = 50

        for i in 0..<total {
            group.enter()
            queue.async {
                self.cache.set(key: "concurrent_key_\(i)", value: i, ttl: 5)
                group.leave()
            }
        }

        // Wait for all sets to schedule then complete
        _ = group.wait(timeout: .now() + 2)
        wait(seconds: 0.2)

        // Validate gets
        var correct = 0
        for i in 0..<total {
            if cache.get(key: "concurrent_key_\(i)", type: Int.self) == i { correct += 1 }
        }
        XCTAssertEqual(correct, total)
    }

    // MARK: - Type-specific Round Trips

    func testChartDataRoundTrip() {
        let coinId = "bitcoin"
        let currency = "usd"
        let days = "7"
        let data: [Double] = [1.0, 2.5, 3.75, 4.0]
        cache.storeChartData(data, for: coinId, currency: currency, days: days)
        wait(seconds: 0.05)
        let fetched = cache.getChartData(for: coinId, currency: currency, days: days)
        XCTAssertEqual(fetched, data)
    }

    func testOHLCDataRoundTrip() {
        let coinId = "bitcoin"
        let currency = "usd"
        let days = "30"
        let now = Date()
        let ohlc = [
            OHLCData(timestamp: now, open: 100, high: 120, low: 90, close: 110),
            OHLCData(timestamp: now.addingTimeInterval(60), open: 110, high: 130, low: 100, close: 120)
        ]
        cache.storeOHLCData(ohlc, for: coinId, currency: currency, days: days)
        wait(seconds: 0.05)
        let fetched = cache.getOHLCData(for: coinId, currency: currency, days: days)
        XCTAssertEqual(fetched?.count, ohlc.count)
        if let first = fetched?.first {
            XCTAssertEqual(first.open, ohlc.first?.open)
            XCTAssertEqual(first.close, ohlc.first?.close)
        }
    }

    // MARK: - Advanced TTL Tests

    func testMultipleSimultaneousExpirations() {
        // Given - Multiple entries with different short TTLs
        let entries = [
            ("key1", "value1", 0.1),
            ("key2", "value2", 0.15),
            ("key3", "value3", 0.2),
            ("key4", "value4", 0.25)
        ]
        
        // When - Store all entries
        for (key, value, ttl) in entries {
            cache.set(key: key, value: value, ttl: ttl)
        }
        wait(seconds: 0.05)
        
        // Then - All should be initially present
        for (key, _, _) in entries {
            XCTAssertNotNil(cache.get(key: key, type: String.self))
        }
        
        // After first expiration (0.12s), key1 should be gone
        wait(seconds: 0.08)
        XCTAssertNil(cache.get(key: "key1", type: String.self))
        XCTAssertNotNil(cache.get(key: "key2", type: String.self))
        XCTAssertNotNil(cache.get(key: "key3", type: String.self))
        
        // After 0.3s, all should be expired
        wait(seconds: 0.2)
        for (key, _, _) in entries {
            XCTAssertNil(cache.get(key: key, type: String.self))
        }
        
        // Memory should be cleaned up
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    func testTTLUpdateOverwritesPreviousEntry() {
        // Given - Initial entry with long TTL
        let key = "ttl_update_test"
        cache.set(key: key, value: "original", ttl: 60)
        wait(seconds: 0.05)
        XCTAssertEqual(cache.get(key: key, type: String.self), "original")
        
        // When - Update with short TTL
        cache.set(key: key, value: "updated", ttl: 0.1)
        wait(seconds: 0.05)
        
        // Then - Should have updated value
        XCTAssertEqual(cache.get(key: key, type: String.self), "updated")
        
        // After short TTL expires
        wait(seconds: 0.2)
        XCTAssertNil(cache.get(key: key, type: String.self))
    }

    func testNegativeTTLBehavesAsZero() {
        // Given - Negative TTL
        let key = "negative_ttl_test"
        cache.set(key: key, value: "test", ttl: -1.0)
        wait(seconds: 0.05)
        
        // Then - Should expire immediately
        XCTAssertNil(cache.get(key: key, type: String.self))
    }

    // MARK: - Memory Threshold Precision Tests

    func testMemoryThresholdExactly50Percent() {
        // Given - Fill cache to exactly 50% of 100MB (50MB)
        // Use calculated size to hit exactly 50%
        let targetSize = 50 * 1024 * 1024 // 50MB
        let imageSize = 2048 * 2048 * 4  // ~16.7MB per image
        let imagesNeeded = 3 // ~50MB total
        
        var keys: [String] = []
        for i in 0..<imagesNeeded {
            let key = "threshold_test_\(i)"
            keys.append(key)
            let image = makeSolidImage(width: 2048, height: 2048)
            cache.set(key: key, value: image, ttl: 60)
        }
        wait(seconds: 0.1)
        
        let statsBeforeWarning = cache.getCacheStats()
        let memoryBeforeWarning = statsBeforeWarning.memoryUsage
        
        // When - Memory warning at exactly 50%
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        wait(seconds: 0.1)
        
        // Then - Should NOT clear cache (not above threshold)
        let remainingCount = keys.compactMap { cache.get(key: $0, type: UIImage.self) }.count
        XCTAssertGreaterThan(remainingCount, 0, "Cache should not be cleared when at exactly 50% threshold")
    }

    func testMemoryThresholdJustAbove50Percent() {
        // Given - Fill cache just above 50% threshold
        let keys = (0..<4).map { "above_threshold_\($0)" }
        for key in keys {
            let largeImage = makeSolidImage(width: 2200, height: 2200) // ~19.4MB each
            cache.set(key: key, value: largeImage, ttl: 60)
        }
        wait(seconds: 0.1)
        
        // When - Memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        wait(seconds: 0.1)
        
        // Then - Should clear cache (above 50% threshold)
        let remainingCount = keys.compactMap { cache.get(key: $0, type: UIImage.self) }.count
        XCTAssertEqual(remainingCount, 0, "Cache should be cleared when above 50% threshold")
        
        let stats = cache.getCacheStats()
        XCTAssertEqual(stats.memoryUsage, 0)
    }

    // MARK: - NSCache Delegate Tests

    func testNSCacheDelegateUpdatesMemoryUsage() {
        // Given - Large entries that will trigger NSCache eviction
        let initialStats = cache.getCacheStats()
        let initialMemory = initialStats.memoryUsage
        
        // Create entries large enough to trigger automatic eviction
        let largeEntryCount = 8
        for i in 0..<largeEntryCount {
            let key = "delegate_test_\(i)"
            let largeImage = makeSolidImage(width: 2500, height: 2500) // ~25MB each
            cache.set(key: key, value: largeImage, ttl: 60)
        }
        wait(seconds: 0.2)
        
        // When - Check final memory usage
        let finalStats = cache.getCacheStats()
        
        // Then - Memory usage should be reasonable (NSCache should have evicted some entries)
        // and delegate should have updated currentMemoryUsage accurately
        XCTAssertLessThan(finalStats.memoryUsage, largeEntryCount * 25 * 1024 * 1024,
                         "NSCache delegate should reduce memory usage when entries are evicted")
        XCTAssertGreaterThanOrEqual(finalStats.memoryUsage, 0,
                                   "Memory usage should never be negative")
    }

    // MARK: - Memory Size Calculation Accuracy Tests

    func testMemorySizeCalculationForDifferentTypes() {
        // Test Double arrays
        let doubles = Array(0..<1000).map { Double($0) }
        cache.set(key: "doubles_test", value: doubles, ttl: 60)
        wait(seconds: 0.05)
        
        // Test Coin arrays (assuming some reasonable memory estimation)
        let mockCoins: [Coin] = [] // Empty array for this test
        cache.set(key: "coins_test", value: mockCoins, ttl: 60)
        wait(seconds: 0.05)
        
        // Test String to Int mapping
        let logoMapping = (0..<100).reduce(into: [Int: String]()) { dict, i in
            dict[i] = "logo_url_\(i)"
        }
        cache.set(key: "logos_test", value: logoMapping, ttl: 60)
        wait(seconds: 0.05)
        
        // Test image memory calculation
        let testImage = makeSolidImage(width: 1000, height: 1000)
        let memoryBefore = cache.getCacheStats().memoryUsage
        cache.set(key: "image_test", value: testImage, ttl: 60)
        wait(seconds: 0.05)
        let memoryAfter = cache.getCacheStats().memoryUsage
        
        // Then - Memory should increase by approximately the image size
        let memoryIncrease = memoryAfter - memoryBefore
        let expectedImageSize = 1000 * 1000 * 4 // 4MB for RGBA
        XCTAssertGreaterThan(memoryIncrease, expectedImageSize / 2,
                            "Memory increase should be proportional to image size")
        XCTAssertLessThan(memoryIncrease, expectedImageSize * 2,
                         "Memory increase should not be wildly larger than expected")
    }

    // MARK: - Advanced Concurrency Tests

    func testConcurrentSetGetWithExpiration() {
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let keys = (0..<20).map { "concurrent_exp_\($0)" }
        
        // Concurrent sets with different TTLs
        for (index, key) in keys.enumerated() {
            group.enter()
            concurrentQueue.async {
                let ttl = index < 10 ? 0.1 : 5.0 // First half expire quickly
                self.cache.set(key: key, value: "value_\(index)", ttl: ttl)
                group.leave()
            }
        }
        
        _ = group.wait(timeout: .now() + 2)
        wait(seconds: 0.05)
        
        // Verify all initially present
        let initialPresent = keys.compactMap { cache.get(key: $0, type: String.self) }
        XCTAssertEqual(initialPresent.count, keys.count)
        
        // Wait for first half to expire
        wait(seconds: 0.2)
        
        // Concurrent gets after partial expiration
        var finalResults: [String?] = Array(repeating: nil, count: keys.count)
        for (index, key) in keys.enumerated() {
            group.enter()
            concurrentQueue.async {
                finalResults[index] = self.cache.get(key: key, type: String.self)
                group.leave()
            }
        }
        
        _ = group.wait(timeout: .now() + 2)
        
        // Then - First half should be expired, second half should remain
        let expiredCount = finalResults.prefix(10).compactMap { $0 }.count
        let remainingCount = finalResults.suffix(10).compactMap { $0 }.count
        
        XCTAssertEqual(expiredCount, 0, "Short TTL entries should be expired")
        XCTAssertEqual(remainingCount, 10, "Long TTL entries should remain")
    }

    // MARK: - Key Edge Cases and Collision Tests

    func testSpecialCharacterKeys() {
        let specialKeys = [
            "key with spaces",
            "key-with-dashes",
            "key_with_underscores",
            "key.with.dots",
            "key/with/slashes",
            "key@with@symbols",
            "🔑emoji🔑key",
            ""
        ]
        
        for key in specialKeys {
            cache.set(key: key, value: "value_for_\(key)", ttl: 60)
        }
        wait(seconds: 0.05)
        
        // Verify all can be retrieved
        for key in specialKeys {
            let retrieved = cache.get(key: key, type: String.self)
            XCTAssertEqual(retrieved, "value_for_\(key)", "Failed for key: '\(key)'")
        }
    }

    func testLargeKeyHandling() {
        let largeKey = String(repeating: "x", count: 10000) // 10KB key
        cache.set(key: largeKey, value: "large_key_value", ttl: 60)
        wait(seconds: 0.05)
        
        XCTAssertEqual(cache.get(key: largeKey, type: String.self), "large_key_value")
    }

    func testEmptyAndNilValueHandling() {
        // Test empty string
        cache.set(key: "empty_string", value: "", ttl: 60)
        wait(seconds: 0.05)
        XCTAssertEqual(cache.get(key: "empty_string", type: String.self), "")
        
        // Test empty array
        cache.set(key: "empty_array", value: [String](), ttl: 60)
        wait(seconds: 0.05)
        XCTAssertEqual(cache.get(key: "empty_array", type: [String].self)?.count, 0)
        
        // Test empty dictionary
        cache.set(key: "empty_dict", value: [String: String](), ttl: 60)
        wait(seconds: 0.05)
        XCTAssertEqual(cache.get(key: "empty_dict", type: [String: String].self)?.count, 0)
    }
}


