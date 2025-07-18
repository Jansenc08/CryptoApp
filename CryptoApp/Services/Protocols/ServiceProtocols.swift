import Foundation
import Combine

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
    
    func cancelAllRequests()
    func getActiveRequestsCount() -> Int
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
} 