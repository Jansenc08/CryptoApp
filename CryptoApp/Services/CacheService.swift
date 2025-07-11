import Foundation
import Combine

// MARK: - Cache Entry
struct CacheEntry<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval
    
    init(data: T, ttl: TimeInterval) {
        self.data = data
        self.timestamp = Date()
        self.ttl = ttl
    }
    
    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

// MARK: - Cache Service
final class CacheService {
    static let shared = CacheService()
    
    private let cache = NSCache<NSString, AnyObject>()
    private let queue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    
    // TTL Constants (in seconds)
    static let coinListTTL: TimeInterval = 30        // 30 seconds for coin list
    static let logoTTL: TimeInterval = 3600         // 1 hour for logos (rarely change)
    static let priceUpdateTTL: TimeInterval = 10    // 10 seconds for price updates
    static let chartDataTTL: TimeInterval = 300     // 5 minutes for chart data
    
    private init() {
        // Set cache limits
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Generic Cache Methods
    
    func get<T>(key: String, type: T.Type) -> T? {
        return queue.sync {
            guard let entry = cache.object(forKey: NSString(string: key)) as? CacheEntry<T> else {
                return nil
            }
            
            if entry.isExpired {
                cache.removeObject(forKey: NSString(string: key))
                return nil
            }
            
            return entry.data
        }
    }
    
    func set<T>(key: String, value: T, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let entry = CacheEntry(data: value, ttl: ttl)
            self.cache.setObject(entry as AnyObject, forKey: NSString(string: key))
        }
    }
    
    func remove(key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: NSString(string: key))
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
    
    // MARK: - Specific Cache Methods
    
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
} 