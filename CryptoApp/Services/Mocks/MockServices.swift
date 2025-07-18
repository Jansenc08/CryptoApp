import Foundation
import Combine

// MARK: - Mock Cache Service

/**
 * MOCK CACHE SERVICE
 * 
 * A mock implementation of CacheServiceProtocol for testing:
 * - Always returns predictable test data
 * - No actual caching (for fast, isolated tests)
 * - Easily configurable behavior
 */
final class MockCacheService: CacheServiceProtocol {
    
    // Test configuration properties
    var shouldReturnCachedData: Bool = true
    var mockCoins: [Coin] = []
    var mockLogos: [Int: String] = [:]
    var mockQuotes: [Int: Quote] = [:]
    var mockChartData: [Double] = []
    
    // MARK: - CacheServiceProtocol Implementation
    
    func getCoinList(limit: Int, start: Int, convert: String, sortType: String, sortDir: String) -> [Coin]? {
        return shouldReturnCachedData ? mockCoins : nil
    }
    
    func storeCoinList(_ coins: [Coin], limit: Int, start: Int, convert: String, sortType: String, sortDir: String) {
        mockCoins = coins
    }
    
    func getCoinLogos() -> [Int: String]? {
        return shouldReturnCachedData ? mockLogos : nil
    }
    
    func storeCoinLogos(_ logos: [Int: String]) {
        mockLogos = logos
    }
    
    func getQuotes(for ids: [Int], convert: String) -> [Int: Quote]? {
        return shouldReturnCachedData ? mockQuotes : nil
    }
    
    func storeQuotes(_ quotes: [Int: Quote], for ids: [Int], convert: String) {
        mockQuotes = quotes
    }
    
    func getChartData(for coinId: String, currency: String, days: String) -> [Double]? {
        return shouldReturnCachedData ? mockChartData : nil
    }
    
    func storeChartData(_ data: [Double], for coinId: String, currency: String, days: String) {
        mockChartData = data
    }
    
    func clearCache() {
        mockCoins = []
        mockLogos = [:]
        mockQuotes = [:]
        mockChartData = []
    }
    
    func clearExpiredEntries() {
        // No-op for mock
    }
}

// MARK: - Mock Request Manager

/**
 * MOCK REQUEST MANAGER
 * 
 * A mock implementation of RequestManagerProtocol for testing:
 * - Returns predictable responses immediately
 * - No actual network requests
 * - Configurable success/failure scenarios
 */
final class MockRequestManager: RequestManagerProtocol {
    
    // Test configuration properties
    var shouldSucceed: Bool = true
    var mockDelay: TimeInterval = 0.0
    var mockError: Error = NetworkError.unknown(NSError(domain: "Test", code: 0))
    
    // Mock data
    var mockCoins: [Coin] = []
    var mockLogos: [Int: String] = [:]
    var mockQuotes: [Int: Quote] = [:]
    var mockChartData: [Double] = []
    
    // MARK: - RequestManagerProtocol Implementation
    
    func executeRequest<T>(
        key: String,
        priority: RequestPriority,
        request: @escaping () -> AnyPublisher<T, Error>
    ) -> AnyPublisher<T, Error> {
        
        if shouldSucceed {
            return Just(())
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .flatMap { _ in request() }
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Coin], NetworkError>
    ) -> AnyPublisher<[Coin], Error> {
        
        if shouldSucceed {
            return Just(mockCoins)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchCoinLogos(
        ids: [Int],
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Int: String], Never>
    ) -> AnyPublisher<[Int: String], Error> {
        
        return Just(mockLogos)
            .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchQuotes(
        ids: [Int],
        convert: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Int: Quote], NetworkError>
    ) -> AnyPublisher<[Int: Quote], Error> {
        
        if shouldSucceed {
            return Just(mockQuotes)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchChartData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[Double], NetworkError>
    ) -> AnyPublisher<[Double], Error> {
        
        if shouldSucceed {
            return Just(mockChartData)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func cancelAllRequests() {
        // No-op for mock
    }
    
    func getActiveRequestsCount() -> Int {
        return 0
    }
}

// MARK: - Mock Coin Service

/**
 * MOCK COIN SERVICE
 * 
 * A mock implementation of CoinServiceProtocol for testing:
 * - Returns predictable data instantly
 * - No actual API calls
 * - Easily configurable for different test scenarios
 */
final class MockCoinService: CoinServiceProtocol {
    
    // Test configuration properties
    var shouldSucceed: Bool = true
    var mockDelay: TimeInterval = 0.0
    var mockError: NetworkError = .invalidResponse
    
    // Mock data
    var mockCoins: [Coin] = []
    var mockLogos: [Int: String] = [:]
    var mockQuotes: [Int: Quote] = [:]
    var mockChartData: [Double] = []
    
    // MARK: - CoinServiceProtocol Implementation
    
    func fetchTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Coin], NetworkError> {
        
        if shouldSucceed {
            return Just(mockCoins)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchCoinLogos(
        forIDs ids: [Int],
        priority: RequestPriority
    ) -> AnyPublisher<[Int: String], Never> {
        
        return Just(mockLogos)
            .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func fetchQuotes(
        for ids: [Int],
        convert: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Int: Quote], NetworkError> {
        
        if shouldSucceed {
            return Just(mockQuotes)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchCoinGeckoChartData(
        for coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Double], NetworkError> {
        
        if shouldSucceed {
            return Just(mockChartData)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
}

// MARK: - Mock Coin Manager

/**
 * MOCK COIN MANAGER
 * 
 * A mock implementation of CoinManagerProtocol for testing ViewModels:
 * - Provides predictable responses for ViewModel testing
 * - No actual business logic
 * - Easy configuration for different test scenarios
 */
final class MockCoinManager: CoinManagerProtocol {
    
    // Test configuration properties
    var shouldSucceed: Bool = true
    var mockDelay: TimeInterval = 0.0
    var mockError: NetworkError = .invalidResponse
    
    // Mock data
    var mockCoins: [Coin] = []
    var mockLogos: [Int: String] = [:]
    var mockQuotes: [Int: Quote] = [:]
    var mockChartData: [Double] = []
    
    // MARK: - CoinManagerProtocol Implementation
    
    func getTopCoins(
        limit: Int,
        convert: String,
        start: Int,
        sortType: String,
        sortDir: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Coin], NetworkError> {
        
        if shouldSucceed {
            return Just(mockCoins)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func getCoinLogos(
        forIDs ids: [Int],
        priority: RequestPriority
    ) -> AnyPublisher<[Int: String], Never> {
        
        return Just(mockLogos)
            .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func getQuotes(
        for ids: [Int],
        convert: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Int: Quote], NetworkError> {
        
        if shouldSucceed {
            return Just(mockQuotes)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
    
    func fetchChartData(
        for geckoID: String,
        range: String,
        currency: String,
        priority: RequestPriority
    ) -> AnyPublisher<[Double], NetworkError> {
        
        if shouldSucceed {
            return Just(mockChartData)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: mockError)
                .delay(for: .seconds(mockDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
    }
}

// MARK: - Test Data Factory

/**
 * TEST DATA FACTORY
 * 
 * Provides sample data for testing and mocking
 */
struct TestDataFactory {
    
    static func createMockCoin(id: Int = 1, symbol: String = "BTC", name: String = "Bitcoin", rank: Int = 1) -> Coin {
        let dateFormatter = ISO8601DateFormatter()
        let currentDateString = dateFormatter.string(from: Date())
        
        let quote = Quote(
            price: 50000.0,
            volume24h: 25000000000.0,
            volumeChange24h: 5.2,
            percentChange1h: 0.5,
            percentChange24h: 2.3,
            percentChange7d: 15.7,
            percentChange30d: 25.4,
            percentChange60d: nil,
            percentChange90d: nil,
            marketCap: 950000000000.0,
            marketCapDominance: 42.5,
            fullyDilutedMarketCap: 1050000000000.0,
            lastUpdated: currentDateString
        )
        
        return Coin(
            id: id,
            name: name,
            symbol: symbol,
            slug: symbol.lowercased(),
            numMarketPairs: 500,
            dateAdded: currentDateString,
            tags: ["mineable", "pow"],
            maxSupply: 21000000,
            circulatingSupply: 19500000,
            totalSupply: 19500000,
            infiniteSupply: false,
            cmcRank: rank,
            lastUpdated: currentDateString,
            quote: ["USD": quote]
        )
    }
    
    static func createMockCoins(count: Int = 10) -> [Coin] {
        return (1...count).map { index in
            createMockCoin(
                id: index,
                symbol: "COIN\(index)",
                name: "Test Coin \(index)",
                rank: index
            )
        }
    }
    
    static func createMockLogos(for coinIds: [Int]) -> [Int: String] {
        return Dictionary(uniqueKeysWithValues: coinIds.map { id in
            (id, "https://example.com/logo\(id).png")
        })
    }
} 