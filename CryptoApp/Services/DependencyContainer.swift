import Foundation
import Combine

/**
 * DEPENDENCY INJECTION CONTAINER
 * 
 * Central container for managing all service dependencies using best practices:
 * - Constructor injection for better testability
 * - Lazy initialization for performance
 * - Protocol-based interfaces for flexibility
 * - Singleton lifetime management where appropriate
 * - Easy mocking and testing support
 * 
 * Usage:
 * ```swift
 * let container = DependencyContainer()
 * let coinManager = container.coinManager()
 * ```
 */
final class DependencyContainer {
    
    // MARK: - Singleton Services (Thread-Safe Lazy Initialization)
    
    private lazy var _cacheService: CacheServiceProtocol = CacheService()
    private lazy var _requestManager: RequestManagerProtocol = RequestManager()
    private lazy var _persistenceService: PersistenceServiceProtocol = PersistenceService()
    private lazy var _coreDataManager: CoreDataManagerProtocol = CoreDataManager()
    private lazy var _coinService: CoinServiceProtocol = CoinService(
        cacheService: cacheService(),
        requestManager: requestManager()
    )
    private lazy var _coinManager: CoinManagerProtocol = CoinManager(
        coinService: coinService()
    )
    private lazy var _watchlistManager: WatchlistManagerProtocol = WatchlistManager(
        coreDataManager: coreDataManager(),
        coinManager: coinManager(),
        persistenceService: persistenceService()
    )
    private lazy var _sharedCoinDataManager: SharedCoinDataManagerProtocol = SharedCoinDataManager(
        coinManager: coinManager()
    )
    
    // MARK: - Singleton Service Access
    
    /**
     * Returns the shared CoinService singleton instance
     */
    func coinService() -> CoinServiceProtocol {
        return _coinService
    }
    
    /**
     * Returns the shared CoinManager singleton instance
     */
    func coinManager() -> CoinManagerProtocol {
        return _coinManager
    }
    
    /**
     * Returns the shared WatchlistManager singleton instance
     * 
     * NOTE: WatchlistManager must be a singleton to ensure all ViewControllers
     * and ViewModels see the same watchlist state in real-time
     */
    func watchlistManager() -> WatchlistManagerProtocol {
        return _watchlistManager
    }
    
    /**
     * Returns the shared SharedCoinDataManager singleton instance
     * 
     * NOTE: SharedCoinDataManager must be a singleton to ensure all ViewControllers
     * and ViewModels see the same shared coin data
     */
    func sharedCoinDataManager() -> SharedCoinDataManagerProtocol {
        return _sharedCoinDataManager
    }
    
    // MARK: - View Models
    
    /**
     * Creates a new CoinListVM instance with injected dependencies
     */
    func coinListViewModel() -> CoinListVM {
        return CoinListVM(
            coinManager: coinManager(),
            sharedCoinDataManager: sharedCoinDataManager(),
            persistenceService: persistenceService()
        )
    }
    
    /**
     * Creates a new SearchVM instance with injected dependencies
     */
    func searchViewModel() -> SearchVM {
        return SearchVM(
            coinManager: coinManager(),
            sharedCoinDataManager: sharedCoinDataManager(),
            persistenceService: persistenceService()
        )
    }
    
    /**
     * Creates a new CoinDetailsVM instance with injected dependencies
     */
    func coinDetailsViewModel(coin: Coin) -> CoinDetailsVM {
        return CoinDetailsVM(
            coin: coin,
            coinManager: coinManager(),
            sharedCoinDataManager: sharedCoinDataManager(),
            requestManager: requestManager()
        )
    }
    
    /**
     * Creates a new WatchlistVM instance with injected dependencies
     */
    func watchlistViewModel() -> WatchlistVM {
        return WatchlistVM(
            watchlistManager: watchlistManager(),
            coinManager: coinManager(),
            sharedCoinDataManager: sharedCoinDataManager()
        )
    }
    
    // MARK: - Singleton Service Accessors
    
    /**
     * Returns the shared CacheService instance
     */
    func cacheService() -> CacheServiceProtocol {
        return _cacheService
    }
    
    /**
     * Returns the shared RequestManager instance
     */
    func requestManager() -> RequestManagerProtocol {
        return _requestManager
    }
    
    /**
     * Returns the shared PersistenceService instance
     */
    func persistenceService() -> PersistenceServiceProtocol {
        return _persistenceService
    }
    
    /**
     * Returns the shared CoreDataManager instance
     */
    func coreDataManager() -> CoreDataManagerProtocol {
        return _coreDataManager
    }
    
    // MARK: - Testing Support
    
    /**
     * Creates a test container with mock dependencies
     * Use this for unit testing to inject mock implementations
     */
    static func testContainer(
        cacheService: CacheServiceProtocol? = nil,
        requestManager: RequestManagerProtocol? = nil,
        persistenceService: PersistenceServiceProtocol? = nil,
        coreDataManager: CoreDataManagerProtocol? = nil
    ) -> DependencyContainer {
        let container = DependencyContainer()
        
        // Override with provided mocks
        if let cacheService = cacheService {
            container._cacheService = cacheService
        }
        if let requestManager = requestManager {
            container._requestManager = requestManager
        }
        if let persistenceService = persistenceService {
            container._persistenceService = persistenceService
        }
        if let coreDataManager = coreDataManager {
            container._coreDataManager = coreDataManager
        }
        
        return container
    }
    
    // MARK: - Container Lifecycle
    
    /**
     * Initializes the dependency container
     * All dependencies are created lazily when first accessed
     */
    init() {
        print("🏗️ DependencyContainer initialized - services will be created lazily")
    }
    
    deinit {
        print("🧹 DependencyContainer deallocated")
    }
}

// MARK: - Global Container Access

/**
 * GLOBAL DEPENDENCY CONTAINER
 * 
 * Provides global access to the main dependency container.
 * This is set up during app initialization and used throughout the app.
 */
class Dependencies {
    static private(set) var container: DependencyContainer!
    
    /**
     * Initializes the global dependency container
     * Call this once during app startup
     */
    static func initialize() {
        container = DependencyContainer()
        print("🏗️ Global Dependencies initialized")
    }
    
    /**
     * Sets a custom dependency container (useful for testing)
     */
    static func setContainer(_ newContainer: DependencyContainer) {
        container = newContainer
        print("🧪 Custom dependency container set")
    }
    
    /**
     * Resets dependencies (useful for testing)
     */
    static func reset() {
        container = nil
        print("🔄 Dependencies reset")
    }
} 