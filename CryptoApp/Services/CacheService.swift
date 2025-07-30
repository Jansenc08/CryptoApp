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
final class CacheService: NSObject, CacheServiceProtocol {

    // MARK: - Initialization
    
    static let shared = CacheService() // Singleton access

    private let cache = NSCache<NSString, AnyObject>() // In-memory store
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent) // Thread-safe access

    // Memory limits
    private var currentMemoryUsage: Int = 0
    private let maxMemoryUsage: Int = 100 * 1024 * 1024 // 100MB max
    private var memoryPressureObserver: NSObjectProtocol?

    // TTL values (in seconds) - Optimized for crypto data patterns
    static let coinListTTL: TimeInterval = 30           // 30s - Rankings change frequently  
    static let logoTTL: TimeInterval = 86400            // 24h - Logos rarely change
    static let priceUpdateTTL: TimeInterval = 15        // 15s - Balance freshness vs performance
    static let chartDataTTL: TimeInterval = 900         // 15min - Reduced API calls while maintaining reasonable freshness
    static let ohlcDataTTL: TimeInterval = 3600         // 1h - OHLC data is expensive to fetch due to rate limits
    
    // Additional crypto-specific TTLs
    static let marketStatsTTL: TimeInterval = 60        // 1min - Market cap, volume
    static let trendingCoinsTTL: TimeInterval = 300     // 5min - Trending lists
    static let coinMetadataTTL: TimeInterval = 3600     // 1h - Name, symbol, description

    /**
     * DEPENDENCY INJECTION INITIALIZER
     * 
     * Internal access allows for:
     * - Testing with fresh instances
     * - Dependency injection in tests
     * - Production singleton pattern
     */
    override init() {
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
                    AppLogger.cache("Memory pressure detected - cleaning cache", level: .warning)
        queue.async(flags: .barrier) {
            if self.currentMemoryUsage > self.maxMemoryUsage / 2 {
                self.cache.removeAllObjects()
                self.currentMemoryUsage = 0
                AppLogger.cache("Cleared all cache due to memory pressure")
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
        AppLogger.cache("Evicting cache entries to free \(bytes) bytes (note: NSCache manages this automatically)")
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

    func getCoinList(limit: Int, start: Int, convert: String, sortType: String = "market_cap", sortDir: String = "desc") -> [Coin]? {
        let key = "coins_\(limit)_\(start)_\(convert)_\(sortType)_\(sortDir)"
        return get(key: key, type: [Coin].self)
    }

    func storeCoinList(_ coins: [Coin], limit: Int, start: Int, convert: String, sortType: String, sortDir: String) {
        let key = "coins_\(limit)_\(start)_\(convert)_\(sortType)_\(sortDir)"
        set(key: key, value: coins, ttl: CacheService.coinListTTL)
    }

    func getCoinLogos() -> [Int: String]? {
        let key = "logos_all"
        return get(key: key, type: [Int: String].self)
    }

    func storeCoinLogos(_ logos: [Int: String]) {
        let key = "logos_all"
        set(key: key, value: logos, ttl: CacheService.logoTTL)
    }

    func getQuotes(for ids: [Int], convert: String) -> [Int: Quote]? {
        let key = "prices_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        return get(key: key, type: [Int: Quote].self)
    }

    func storeQuotes(_ quotes: [Int: Quote], for ids: [Int], convert: String) {
        let key = "prices_\(ids.sorted().map(String.init).joined(separator: "_"))_\(convert)"
        set(key: key, value: quotes, ttl: CacheService.priceUpdateTTL)
    }

    func getChartData(for coinId: String, currency: String, days: String) -> [Double]? {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        return get(key: key, type: [Double].self)
    }

    func storeChartData(_ data: [Double], for coinId: String, currency: String, days: String) {
        let key = "chart_\(coinId)_\(currency)_\(days)"
        set(key: key, value: data, ttl: CacheService.chartDataTTL)
    }
    
    func getOHLCData(for coinId: String, currency: String, days: String) -> [OHLCData]? {
        let key = "ohlc_\(coinId)_\(currency)_\(days)"
        return get(key: key, type: [OHLCData].self)
    }
    
    func storeOHLCData(_ data: [OHLCData], for coinId: String, currency: String, days: String) {
        let key = "ohlc_\(coinId)_\(currency)_\(days)"
        set(key: key, value: data, ttl: CacheService.ohlcDataTTL)
    }
    
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.currentMemoryUsage = 0
            AppLogger.cache("Cache cleared - all objects removed")
        }
    }
    
    func clearExpiredEntries() {
        queue.async(flags: .barrier) {
            // This method would iterate through cache and remove expired entries
            // For NSCache, we rely on automatic eviction based on memory pressure
            AppLogger.cache("Expired entries cleanup requested (automatic for NSCache)")
        }
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
            AppLogger.cache("Cache evicted entry, freed \(entry.memorySize) bytes")
        }
    }
}
