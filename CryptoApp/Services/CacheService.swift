import Foundation
import Combine
import UIKit

// MARK: - Cache Entry
// This is centralized, thread-safe memory cache that stores: Coin lists, Coin logos, Price updates, Chart data
// Uses NSCache under the hood and supports:
// Expiration (via TTL: Time To Live) , Memory pressure handling, Type-safe generic access, Thread-safe reads/writes using GCD (DispatchQueue)

// A wrapper for cached values that includes expiration logic and memory size estimation
struct CacheEntry<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval
    let memorySize: Int

    init(data: T, ttl: TimeInterval, memorySize: Int = 0) {
        self.data = data
        self.timestamp = Date()
        self.ttl = ttl
        self.memorySize = memorySize
    }

    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Cache Service

// A centralized caching service for coins, logos, price updates, and chart data
final class CacheService: NSObject {

    static let shared = CacheService() // Singleton access

    private let cache = NSCache<NSString, AnyObject>() // In-memory store
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent) // Thread-safe access

    // Memory limits
    private var currentMemoryUsage: Int = 0
    private let maxMemoryUsage: Int = 100 * 1024 * 1024 // 100MB max
    private var memoryPressureObserver: NSObjectProtocol?

    // TTL values (in seconds)
    static let coinListTTL: TimeInterval = 30
    static let logoTTL: TimeInterval = 3600
    static let priceUpdateTTL: TimeInterval = 10
    // I increased this from 5 minutes (300s) to 10 minutes (600s) for better filter performance!
    // This means chart data stays cached longer, so when users switch between filters,
    // they're more likely to get instant responses instead of waiting for new API calls
    static let chartDataTTL: TimeInterval = 600  // Increased from 5 minutes to 10 minutes for better filter performance

    private override init() {
        super.init()
        setupCache()
        setupMemoryPressureHandling()
    }

    private func setupCache() {
        cache.countLimit = 200
        cache.totalCostLimit = maxMemoryUsage
        cache.delegate = self
    }

    private func setupMemoryPressureHandling() {
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
    }

    private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected - cleaning cache")
        queue.async(flags: .barrier) {
            if self.currentMemoryUsage > self.maxMemoryUsage / 2 {
                self.cache.removeAllObjects()
                self.currentMemoryUsage = 0
                print("🧹 Cleared all cache due to memory pressure")
            }
        }
    }



    // MARK: - Generic Get/Set Methods

    //
    func get<T>(key: String, type: T.Type) -> T? {
        return queue.sync {
            guard let entry = cache.object(forKey: NSString(string: key)) as? CacheEntry<T> else {
                return nil
            }

            if entry.isExpired {
                cache.removeObject(forKey: NSString(string: key))
                currentMemoryUsage -= entry.memorySize
                return nil
            }

            return entry.data
        }
    }

    func set<T>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let memorySize = self.calculateMemorySize(for: value)

            if self.currentMemoryUsage + memorySize > self.maxMemoryUsage {
                self.evictOldestEntries(toFreeBytes: memorySize)
            }

            let entry = CacheEntry(data: value, ttl: ttl, memorySize: memorySize)
            self.cache.setObject(entry as AnyObject, forKey: NSString(string: key), cost: memorySize)
            self.currentMemoryUsage += memorySize
        }
    }

    // MARK: - Memory Size Estimation

    private func calculateMemorySize<T>(for value: T) -> Int {
        switch value {
        case let doubles as [Double]:
            return doubles.count * MemoryLayout<Double>.size + 32
        case let coins as [Coin]:
            return coins.count * 500 + 64
        case let logos as [Int: String]:
            return logos.count * 100 + 32
        case let quotes as [Int: Quote]:
            return quotes.count * 200 + 32
        default:
            return 1024
        }
    }

    private func evictOldestEntries(toFreeBytes bytes: Int) {
        print("💾 Evicting cache entries to free \(bytes) bytes (note: NSCache manages this automatically)")
    }

    // MARK: - Removal / Clearing

    func remove(key: String) {
        queue.async(flags: .barrier) {
            if let entry = self.cache.object(forKey: NSString(string: key)) as? CacheEntry<Any> {
                self.currentMemoryUsage -= entry.memorySize
            }
            self.cache.removeObject(forKey: NSString(string: key))
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.currentMemoryUsage = 0
        }
    }

    // MARK: - Statistics

    func getCacheStats() -> (count: Int, memoryUsage: Int, maxMemory: Int) {
        return queue.sync {
            return (
                count: cache.countLimit,
                memoryUsage: currentMemoryUsage,
                maxMemory: maxMemoryUsage
            )
        }
    }

    // MARK: - Type-Specific Getters/Setters

    func getCoinList(limit: Int, start: Int, convert: String) -> [Coin]? {
        let key = "coins_\(limit)_\(start)_\(convert)"
        return get(key: key, type: [Coin].self)
    }

    func setCoinList(_ coins: [Coin], limit: Int, start: Int, convert: String) {
        let key = "coins_\(limit)_\(start)_\(convert)"
        set(key: key, value: coins, ttl: CacheService.coinListTTL)
    }

    func getCoinLogos(forIDs ids: [Int]) -> [Int: String]? {
        let key = "logos_\(ids.sorted().map(String.init).joined(separator: "_"))"
        return get(key: key, type: [Int: String].self)
    }

    func setCoinLogos(_ logos: [Int: String], forIDs ids: [Int]) {
        let key = "logos_\(ids.sorted().map(String.init).joined(separator: "_"))"
        set(key: key, value: logos, ttl: CacheService.logoTTL)
    }

    func getPriceUpdates(forIDs ids: [Int], convert: String) -> [Int: Quote]? {
        let key = "prices_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        return get(key: key, type: [Int: Quote].self)
    }

    func setPriceUpdates(_ quotes: [Int: Quote], forIDs ids: [Int], convert: String) {
        let key = "prices_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        set(key: key, value: quotes, ttl: CacheService.priceUpdateTTL)
    }

    func getChartData(coinId: String, currency: String, days: String) -> [Double]? {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        return get(key: key, type: [Double].self)
    }

    func setChartData(_ data: [Double], coinId: String, currency: String, days: String) {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        set(key: key, value: data, ttl: CacheService.chartDataTTL)
    }

    deinit {
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - NSCacheDelegate

extension CacheService: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        if let entry = obj as? CacheEntry<Any> {
            queue.async(flags: .barrier) {
                self.currentMemoryUsage -= entry.memorySize
            }
            print("♻️ Cache evicted entry, freed \(entry.memorySize) bytes")
        }
    }
}
