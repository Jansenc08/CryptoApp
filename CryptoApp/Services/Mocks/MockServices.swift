import Foundation
import Combine
import CoreData

// MARK: - Mock services:
/**
* MockCacheService, MockPersistenceService,
* MockCoreDataManager, MockRequestManager, MockCoinService,
* MockCoinManager, MockWatchlistManager, MockSharedCoinDataManager.
*/

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
    var mockOHLCData: [OHLCData] = []
    
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
    
    func getOHLCData(for coinId: String, currency: String, days: String) -> [OHLCData]? {
        return shouldReturnCachedData ? mockOHLCData : nil
    }
    
    func storeOHLCData(_ data: [OHLCData], for coinId: String, currency: String, days: String) {
        mockOHLCData = data
    }
    
    func clearCache() {
        mockCoins = []
        mockLogos = [:]
        mockQuotes = [:]
        mockChartData = []
        mockOHLCData = []
    }
    
    func clearExpiredEntries() {
        // No-op for mock
    }
}

// MARK: - Mock Persistence Service

/**
 * MOCK PERSISTENCE SERVICE
 * 
 * A mock implementation of PersistenceServiceProtocol for testing:
 * - In-memory storage (no actual UserDefaults)
 * - Predictable behavior
 * - Easily configurable for different test scenarios
 */
final class MockPersistenceService: PersistenceServiceProtocol {
    
    // In-memory storage
    private var storedCoins: [Coin] = []
    private var storedLogos: [Int: String] = [:]
    private var lastCacheTime: Date?
    
    // Test configuration
    var shouldSimulateExpiredCache: Bool = false
    var customCacheAge: TimeInterval = 300 // 5 minutes default
    
    // MARK: - PersistenceServiceProtocol Implementation
    
    func saveCoinList(_ coins: [Coin]) {
        storedCoins = coins
        lastCacheTime = Date()
    }
    
    func loadCoinList() -> [Coin]? {
        return storedCoins.isEmpty ? nil : storedCoins
    }
    
    func saveCoinLogos(_ logos: [Int: String]) {
        storedLogos = logos
    }
    
    func loadCoinLogos() -> [Int: String]? {
        return storedLogos.isEmpty ? nil : storedLogos
    }
    
    func getLastCacheTime() -> Date? {
        return lastCacheTime
    }
    
    func isCacheExpired(maxAge: TimeInterval = 300) -> Bool {
        if shouldSimulateExpiredCache { return true }
        
        guard let lastTime = lastCacheTime else { return true }
        return Date().timeIntervalSince(lastTime) > maxAge
    }
    
    func clearCache() {
        storedCoins = []
        storedLogos = [:]
        lastCacheTime = nil
    }
    
    func getOfflineData() -> (coins: [Coin], logos: [Int: String])? {
        guard !storedCoins.isEmpty else { return nil }
        return (coins: storedCoins, logos: storedLogos)
    }
    
    func saveOfflineData(coins: [Coin], logos: [Int: String]) {
        saveCoinList(coins)
        saveCoinLogos(logos)
    }
}

// MARK: - Mock Core Data Manager

/**
 * MOCK CORE DATA MANAGER
 * 
 * A mock implementation of CoreDataManagerProtocol for testing:
 * - In-memory storage (no actual Core Data)
 * - Predictable behavior for watchlist operations
 * - Thread-safe operations
 */
final class MockCoreDataManager: CoreDataManagerProtocol {
    
    // Mock in-memory storage
    private var mockObjects: [NSManagedObject] = []
    private let queue = DispatchQueue(label: "mock.coredata.queue", attributes: .concurrent)
    
    // Test configuration
    var shouldFailSave: Bool = false
    var shouldFailFetch: Bool = false
    
    // Mock context (not used in mock implementation)
    var context: NSManagedObjectContext {
        return NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    }
    
    // MARK: - CoreDataManagerProtocol Implementation
    
    func save() {
        guard !shouldFailSave else {
            AppLogger.database("Mock Core Data save failed (configured to fail)", level: .error)
            return
        }
        // Mock save - no actual operation needed
        AppLogger.database("Mock Core Data save succeeded")
    }
    
    func delete<T: NSManagedObject>(_ object: T) {
        queue.async(flags: .barrier) {
            self.mockObjects.removeAll { $0 === object }
        }
        AppLogger.database("Mock Core Data deleted object")
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type) -> [T] {
        guard !shouldFailFetch else {
            AppLogger.database("Mock Core Data fetch failed (configured to fail)", level: .error)
            return []
        }
        
        return queue.sync {
            return mockObjects.compactMap { $0 as? T }
        }
    }
    
    func fetch<T: NSManagedObject>(_ objectType: T.Type, where predicate: NSPredicate) -> [T] {
        guard !shouldFailFetch else {
            AppLogger.database("Mock Core Data fetch with predicate failed (configured to fail)", level: .error)
            return []
        }
        
        return queue.sync {
            return mockObjects.compactMap { $0 as? T }
                .filter { object in
                    // Simple predicate evaluation for testing
                    // In a real implementation, this would be more sophisticated
                    return true
                }
        }
    }
    
    // Specific methods for WatchlistItem to avoid ambiguity
    func fetchWatchlistItems() -> [WatchlistItem] {
        guard !shouldFailFetch else {
            AppLogger.database("Mock Core Data fetch watchlist items failed (configured to fail)", level: .error)
            return []
        }
        
        return queue.sync {
            return mockObjects.compactMap { $0 as? WatchlistItem }
        }
    }
    
    func fetchWatchlistItems(where predicate: NSPredicate) -> [WatchlistItem] {
        guard !shouldFailFetch else {
            AppLogger.database("Mock Core Data fetch watchlist items with predicate failed (configured to fail)", level: .error)
            return []
        }
        
        return queue.sync {
            return mockObjects.compactMap { $0 as? WatchlistItem }
                .filter { item in
                    // Simple predicate evaluation for testing
                    // In a real implementation, this would be more sophisticated
                    return true
                }
        }
    }
    
    // MARK: - Test Helper Methods
    
    func addMockObject<T: NSManagedObject>(_ object: T) {
        queue.async(flags: .barrier) {
            self.mockObjects.append(object)
        }
    }
    
    func clearAllMockObjects() {
        queue.async(flags: .barrier) {
            self.mockObjects.removeAll()
        }
    }
    
    func getMockObjectCount() -> Int {
        return queue.sync { mockObjects.count }
    }
}

// MARK: - Mock Watchlist Manager

/**
 * MOCK WATCHLIST MANAGER
 * 
 * A mock implementation of WatchlistManagerProtocol for testing:
 * - In-memory watchlist storage
 * - Predictable behavior
 * - Publisher support for reactive testing
 */
final class MockWatchlistManager: WatchlistManagerProtocol {
    
    // Mock storage
    private var watchlistCoins: [Coin] = []
    private var mockWatchlistItems: [WatchlistItem] = []
    private let watchlistSubject = CurrentValueSubject<[Coin], Never>([])
    
    // Use @Published to provide actual Published.Publisher type
    @Published private var _watchlistItems: [WatchlistItem] = []
    
    // Test configuration
    var shouldFailOperations: Bool = false
    var operationDelay: TimeInterval = 0.0
    
    // MARK: - Protocol Properties
    
    var watchlistItems: [WatchlistItem] {
        return _watchlistItems
    }
    
    var watchlistItemsPublisher: Published<[WatchlistItem]>.Publisher {
        return $_watchlistItems
    }
    
    // MARK: - WatchlistManagerProtocol Implementation
    
    func getWatchlistCoins() -> [Coin] {
        return watchlistCoins
    }
    
    func addCoinToWatchlist(_ coin: Coin) {
        guard !shouldFailOperations else {
            print("❌ Mock watchlist add failed (configured to fail)")
            return
        }
        
        if !watchlistCoins.contains(where: { $0.id == coin.id }) {
            watchlistCoins.append(coin)
            watchlistSubject.send(watchlistCoins)
            print("✅ Mock added \(coin.symbol) to watchlist")
        }
    }
    
    func removeCoinFromWatchlist(_ coin: Coin) {
        guard !shouldFailOperations else {
            print("❌ Mock watchlist remove failed (configured to fail)")
            return
        }
        
        watchlistCoins.removeAll { $0.id == coin.id }
        watchlistSubject.send(watchlistCoins)
        print("✅ Mock removed \(coin.symbol) from watchlist")
    }
    
    func isInWatchlist(_ coin: Coin) -> Bool {
        return watchlistCoins.contains { $0.id == coin.id }
    }
    
    func clearWatchlist() {
        guard !shouldFailOperations else {
            print("❌ Mock watchlist clear failed (configured to fail)")
            return
        }
        
        watchlistCoins.removeAll()
        _watchlistItems.removeAll()
        watchlistSubject.send(watchlistCoins)
        print("✅ Mock cleared watchlist")
    }
    
    // MARK: - Core Protocol Methods
    
    func addToWatchlist(_ coin: Coin, logoURL: String?) {
        addCoinToWatchlist(coin)
    }
    
    func removeFromWatchlist(coinId: Int) {
        if let coin = watchlistCoins.first(where: { $0.id == coinId }) {
            removeCoinFromWatchlist(coin)
        }
    }
    
    func isInWatchlist(coinId: Int) -> Bool {
        return watchlistCoins.contains { $0.id == coinId }
    }
    
    func getWatchlistCount() -> Int {
        return watchlistCoins.count
    }
    
    func getPerformanceMetrics() -> [String: Any] {
        return [
            "mockWatchlistCount": watchlistCoins.count,
            "operationsEnabled": !shouldFailOperations,
            "operationDelay": operationDelay
        ]
    }
    
    // MARK: - Test Helper Methods
    
    func setMockWatchlist(_ coins: [Coin]) {
        watchlistCoins = coins
        watchlistSubject.send(watchlistCoins)
    }
    
    func getMockWatchlistCount() -> Int {
        return watchlistCoins.count
    }
    
    // MARK: - Batch Operations
    
    func addMultipleToWatchlist(_ coins: [Coin], logoURLs: [Int: String]) {
        for coin in coins {
            addToWatchlist(coin, logoURL: logoURLs[coin.id])
        }
    }
    
    func removeMultipleFromWatchlist(coinIds: [Int]) {
        for coinId in coinIds {
            removeFromWatchlist(coinId: coinId)
        }
    }
    
    func printDatabaseContents() {
        print("📋 Mock Watchlist Database Contents:")
        print("   Watchlist coins: \(watchlistCoins.count)")
        for coin in watchlistCoins {
            print("   - \(coin.name) (\(coin.symbol))")
        }
    }
}

// MARK: - Mock Shared Coin Data Manager

/**
 * MOCK SHARED COIN DATA MANAGER
 * 
 * A mock implementation of SharedCoinDataManagerProtocol for testing:
 * - Controllable data updates
 * - Publisher support for reactive testing
 * - No automatic updates (manual control)
 */
final class MockSharedCoinDataManager: SharedCoinDataManagerProtocol {
    
    // Mock storage
    private let coinsSubject = CurrentValueSubject<[Coin], Never>([])
    private let errorsSubject = PassthroughSubject<Error, Never>()
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let isFetchingFreshDataSubject = CurrentValueSubject<Bool, Never>(false)
    
    // Test configuration
    var shouldFailUpdates: Bool = false
    var autoUpdateEnabled: Bool = false
    
    // MARK: - SharedCoinDataManagerProtocol Implementation
    
    var allCoins: AnyPublisher<[Coin], Never> { coinsSubject.eraseToAnyPublisher() }
    var errors: AnyPublisher<Error, Never> { errorsSubject.eraseToAnyPublisher() }
    var isLoading: AnyPublisher<Bool, Never> { isLoadingSubject.eraseToAnyPublisher() }
    var isFetchingFreshData: AnyPublisher<Bool, Never> { isFetchingFreshDataSubject.eraseToAnyPublisher() }
    var currentCoins: [Coin] { coinsSubject.value }
    
    func forceUpdate() {
        guard !shouldFailUpdates else { return }
        isLoadingSubject.send(true)
        if currentCoins.isEmpty { isFetchingFreshDataSubject.send(true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let mockCoins = TestDataFactory.createMockCoins(count: 10)
            self?.coinsSubject.send(mockCoins)
            self?.isLoadingSubject.send(false)
            self?.isFetchingFreshDataSubject.send(false)
        }
    }
    
    func startAutoUpdate() {
        autoUpdateEnabled = true
        if currentCoins.isEmpty { forceUpdate() }
    }
    
    func stopAutoUpdate() {
        autoUpdateEnabled = false
        isLoadingSubject.send(false)
        isFetchingFreshDataSubject.send(false)
    }
    
    // MARK: - Test Helper Methods
    func setMockCoins(_ coins: [Coin]) { coinsSubject.send(coins) }
    func getMockCoinCount() -> Int { currentCoins.count }
    func getCoinsForIds(_ ids: [Int]) -> [Coin] { currentCoins.filter { ids.contains($0.id) } }
    
    // New: public helper to emit errors for tests
    func emitError(_ error: Error) { errorsSubject.send(error) }
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
    var mockOHLCData: [OHLCData] = []
    
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
    
    func fetchOHLCData(
        coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority,
        apiCall: @escaping () -> AnyPublisher<[OHLCData], NetworkError>
    ) -> AnyPublisher<[OHLCData], Error> {
        
        if shouldSucceed {
            return Just(mockOHLCData)
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
    
    func getCooldownStatus() -> (isInCooldown: Bool, remainingSeconds: Int) {
        return (false, 0) // Mock never in cooldown
    }
    
    func shouldPreferCache() -> Bool {
        return false // Mock doesn't prefer cache by default
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
    var mockOHLCData: [OHLCData] = []
    
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
    
    func fetchCoinGeckoOHLCData(
        for coinId: String,
        currency: String,
        days: String,
        priority: RequestPriority
    ) -> AnyPublisher<[OHLCData], NetworkError> {
        
        if shouldSucceed {
            return Just(mockOHLCData)
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
    var mockOHLCData: [OHLCData] = []
    
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
    
    func fetchOHLCData(
        for geckoID: String,
        range: String,
        currency: String,
        priority: RequestPriority
    ) -> AnyPublisher<[OHLCData], NetworkError> {
        
        if shouldSucceed {
            return Just(mockOHLCData)
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
    
    static func createMockChartData(points: Int = 100) -> [Double] {
        return (0..<points).map { index in
            // Generate realistic-looking price data with some variation
            let basePrice = 50000.0
            let variation = sin(Double(index) * 0.1) * 5000 + Double.random(in: -1000...1000)
            return basePrice + variation
        }
    }
    
    static func createMockOHLCData(candles: Int = 24) -> [OHLCData] {
        return (0..<candles).map { index in
            let basePrice = 50000.0 + Double(index) * 100
            let open = basePrice + Double.random(in: -500...500)
            let close = basePrice + Double.random(in: -500...500)
            let high = max(open, close) + Double.random(in: 0...1000)
            let low = min(open, close) - Double.random(in: 0...1000)
            let timestamp = Date().addingTimeInterval(TimeInterval(index * 3600))
            
            return OHLCData(
                timestamp: timestamp,
                open: open,
                high: high,
                low: low,
                close: close
            )
        }
    }
}

// MARK: - Test Container Factory

/**
 * TEST CONTAINER FACTORY
 * 
 * Creates pre-configured dependency containers for different test scenarios
 */
struct TestContainerFactory {
    
    /**
     * Creates a container with all mock services
     */
    static func createMockContainer() -> DependencyContainer {
        let mockCache = MockCacheService()
        let mockRequest = MockRequestManager()
        let mockPersistence = MockPersistenceService()
        let mockCoreData = MockCoreDataManager()
        
        // Configure with test data
        let mockCoins = TestDataFactory.createMockCoins(count: 10)
        mockCache.mockCoins = mockCoins
        mockRequest.mockCoins = mockCoins
        mockPersistence.saveCoinList(mockCoins)
        
        return DependencyContainer.testContainer(
            cacheService: mockCache,
            requestManager: mockRequest,
            persistenceService: mockPersistence,
            coreDataManager: mockCoreData
        )
    }
    
    /**
     * Creates a container configured for failure scenarios
     */
    static func createFailureTestContainer() -> DependencyContainer {
        let mockCache = MockCacheService()
        let mockRequest = MockRequestManager()
        let mockPersistence = MockPersistenceService()
        let mockCoreData = MockCoreDataManager()
        
        // Configure for failures
        mockCache.shouldReturnCachedData = false
        mockRequest.shouldSucceed = false
        mockPersistence.shouldSimulateExpiredCache = true
        mockCoreData.shouldFailSave = true
        
        return DependencyContainer.testContainer(
            cacheService: mockCache,
            requestManager: mockRequest,
            persistenceService: mockPersistence,
            coreDataManager: mockCoreData
        )
    }
    
    /**
     * Creates a container with delayed responses for testing loading states
     */
    static func createDelayedTestContainer(delay: TimeInterval = 1.0) -> DependencyContainer {
        let mockCache = MockCacheService()
        let mockRequest = MockRequestManager()
        let mockPersistence = MockPersistenceService()
        let mockCoreData = MockCoreDataManager()
        
        // Configure delays
        mockRequest.mockDelay = delay
        
        // Configure with test data
        let mockCoins = TestDataFactory.createMockCoins(count: 10)
        mockRequest.mockCoins = mockCoins
        
        return DependencyContainer.testContainer(
            cacheService: mockCache,
            requestManager: mockRequest,
            persistenceService: mockPersistence,
            coreDataManager: mockCoreData
        )
    }
} 
