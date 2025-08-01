import Foundation
import Combine
import CoreData

// MARK: - Cache Service Protocol

/**
 * CACHE SERVICE PROTOCOL
 * 
 * Defines the interface for caching operations, allowing for:
 * - Easy testing with mock implementations
 * - Swappable cache strategies (memory, disk, hybrid)
 * - Clear contract for cache behavior
 */
protocol CacheServiceProtocol {
    func getCoinList(limit: Int, start: Int, convert: String, sortType: String, sortDir: String) -> [Coin]?
    func storeCoinList(_ coins: [Coin], limit: Int, start: Int, convert: String, sortType: String, sortDir: String)
    func getCoinLogos() -> [Int: String]?
    func storeCoinLogos(_ logos: [Int: String])
    func getQuotes(for ids: [Int], convert: String) -> [Int: Quote]?
    func storeQuotes(_ quotes: [Int: Quote], for ids: [Int], convert: String)
    func getChartData(for coinId: String, currency: String, days: String) -> [Double]?
    func storeChartData(_ data: [Double], for coinId: String, currency: String, days: String)
    func getOHLCData(for coinId: String, currency: String, days: String) -> [OHLCData]?
    func storeOHLCData(_ data: [OHLCData], for coinId: String, currency: String, days: String)
    func clearCache()
    func clearExpiredEntries()
}

// MARK: - Request Manager Protocol

/**
 * REQUEST MANAGER PROTOCOL
 * 
 * Defines the interface for request management, enabling:
 * - Testable request handling with mock implementations
 * - Different rate limiting strategies
 * - Priority queue management abstraction
 */
protocol RequestManagerProtocol {
    func executeRequest<T>(
        key: String,
        priority: RequestPriority,
        request: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Error>
    
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Coin], NetworkError>
    ) -> AnyPublisher<[Coin], Error>
    
    func fetchCoinLogos(
        ids: [Int],
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Int: String], Never>
    ) -> AnyPublisher<[Int: String], Error>
    
    func fetchQuotes(
        ids: [Int],
        convert: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Int: Quote], NetworkError>
    ) -> AnyPublisher<[Int: Quote], Error>
    
    func fetchChartData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Double], NetworkError>
    ) -> AnyPublisher<[Double], Error>
    
    func fetchOHLCData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[OHLCData], NetworkError>
    ) -> AnyPublisher<[OHLCData], Error>
    
    func cancelAllRequests()
    func getActiveRequestsCount() -> Int
    func getCooldownStatus() -> (isInCooldown: Bool, remainingSeconds: Int)
    func shouldPreferCache() -> Bool
}

// MARK: - Coin Service Protocol

/**
 * COIN SERVICE PROTOCOL
 * 
 * Defines the interface for coin data operations, allowing:
 * - Mock implementations for testing
 * - Different data sources (API, local, hybrid)
 * - Clean separation of concerns
 */
protocol CoinServiceProtocol {
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Coin], NetworkError>
    
    func fetchCoinLogos(
        forIDs ids: [Int],
        priority: RequestPriority
    ) -> AnyPublisher<[Int: String], Never>
    
    func fetchQuotes(
        for ids: [Int],
        convert: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Int: Quote], NetworkError>
    
    func fetchCoinGeckoChartData(
        for coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Double], NetworkError>
    
    func fetchCoinGeckoOHLCData(
        for coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority
    ) -> AnyPublisher<[OHLCData], NetworkError>
}

// MARK: - Persistence Service Protocol

/**
 * PERSISTENCE SERVICE PROTOCOL
 * 
 * Defines the interface for data persistence operations, enabling:
 * - Mock implementations for testing
 * - Different storage strategies (UserDefaults, CoreData, etc.)
 * - Clear separation of concerns
 */
protocol PersistenceServiceProtocol {
    func saveCoinList(_ coins: [Coin])
    func loadCoinList() -> [Coin]?
    func saveCoinLogos(_ logos: [Int: String])
    func loadCoinLogos() -> [Int: String]?
    func getLastCacheTime() -> Date?
    func isCacheExpired(maxAge: TimeInterval) -> Bool
    func clearCache()
    func getOfflineData() -> (coins: [Coin], logos: [Int: String])?
    func saveOfflineData(coins: [Coin], logos: [Int: String])
}

// MARK: - Core Data Manager Protocol

/**
 * CORE DATA MANAGER PROTOCOL
 * 
 * Defines the interface for Core Data operations, enabling:
 * - Mock implementations for testing
 * - Different storage backends
 * - Better testability and modularity
 */
protocol CoreDataManagerProtocol {
    var context: NSManagedObjectContext { get }
    func save()
    func delete<T: NSManagedObject>(_ object: T)
    func fetch<T: NSManagedObject>(_ objectType: T.Type) -> [T]
    func fetch<T: NSManagedObject>(_ objectType: T.Type, where predicate: NSPredicate) -> [T]
    
    // Specific methods for WatchlistItem to avoid ambiguity
    func fetchWatchlistItems() -> [WatchlistItem]
    func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem]
}

// MARK: - Watchlist Manager Protocol

/**
 * WATCHLIST MANAGER PROTOCOL
 * 
 * Defines the interface for watchlist operations, enabling:
 * - Mock implementations for testing
 * - Different storage strategies
 * - Clear separation of concerns
 */
protocol WatchlistManagerProtocol {
    // MARK: - Published Properties
    var watchlistItems: [WatchlistItem] { get }
    var watchlistItemsPublisher: Published<[WatchlistItem]>.Publisher { get }
    
    // MARK: - Core Methods
    func addToWatchlist(_ coin: Coin, logoURL: String?)
    func removeFromWatchlist(coinId: Int)
    func isInWatchlist(coinId: Int) -> Bool
    func isInWatchlist(_ coin: Coin) -> Bool
    func getWatchlistCount() -> Int
    func getWatchlistCoins() -> [Coin]
    func getPerformanceMetrics() -> [String: Any]
    
    // MARK: - Convenience Methods for Protocol Compatibility
    func addCoinToWatchlist(_ coin: Coin)
    func removeCoinFromWatchlist(_ coin: Coin)
    
    // MARK: - Batch Operations
    func addMultipleToWatchlist(_ coins: [Coin], logoURLs: [Int: String])
    func removeMultipleFromWatchlist(coinIds: [Int])
    func clearWatchlist()
    func printDatabaseContents()
}

// MARK: - Coin Manager Protocol

/**
 * COIN MANAGER PROTOCOL
 * 
 * Defines the interface for high-level coin operations, enabling:
 * - Easy mocking for ViewModel testing
 * - Swappable business logic implementations
 * - Clear API contract for ViewModels
 */
protocol CoinManagerProtocol {
    func getTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Coin], NetworkError>
    
    func getCoinLogos(
        forIDs ids: [Int],
        priority: RequestPriority
    ) -> AnyPublisher<[Int: String], Never>
    
    func getQuotes(
        for ids: [Int],
        convert: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Int: Quote], NetworkError>
    
    func fetchChartData(
        for geckoID: String,
        range: String,
        currency: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Double], NetworkError>
    
    func fetchOHLCData(
        for geckoID: String,
        range: String,
        currency: String,
        priority: RequestPriority
    ) -> AnyPublisher<[OHLCData], NetworkError>
}

// MARK: - Shared Coin Data Manager Protocol

/**
 * SHARED COIN DATA MANAGER PROTOCOL
 * 
 * Defines the interface for shared coin data management, enabling:
 * - Mock implementations for testing
 * - Different data sharing strategies
 * - Clear separation of concerns
 */
protocol SharedCoinDataManagerProtocol {
    var allCoins: AnyPublisher<[Coin], Never> { get }
    var errors: AnyPublisher<Error, Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    var isFetchingFreshData: AnyPublisher<Bool, Never> { get }
    var currentCoins: [Coin] { get }
    func forceUpdate()
    func startAutoUpdate()
    func stopAutoUpdate()
    func getCoinsForIds(_ ids: [Int]) -> [Coin]
} 