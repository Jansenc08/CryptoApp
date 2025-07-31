//
//  SearchVM.swift
//  CryptoApp
//
//  Created by AI Assistant on 1/7/25.
//

import Foundation
import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let coinListCacheUpdated = Notification.Name("coinListCacheUpdated")
}

/**
 * SearchVM
 * 
 * ARCHITECTURE PATTERN: MVVM (Model-View-ViewModel)
 * - Handles search logic and state management
 * - Uses Combine debounce for efficient search input handling
 * - Filters existing coin data locally for best performance
 * - Integrates with existing CoinManager and caching system
 * 
 * SEARCH STRATEGY:
 * - Local filtering for instant results (uses cached coin data)
 * - Debounced input to prevent excessive filtering operations
 * - Searches across coin name, symbol, and slug
 * - Case-insensitive search with partial matching
 */
final class SearchVM: ObservableObject {
    
    // MARK: - Private Subjects (Internal State Management)
    
    /**
     * REACTIVE STATE MANAGEMENT WITH SUBJECTS
     * 
     * Using CurrentValueSubject for state that needs current values
     * This gives us more control over when and how values are published
     */
    
    private let searchTextSubject = CurrentValueSubject<String, Never>("")
    private let searchResultsSubject = CurrentValueSubject<[Coin], Never>([])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorMessageSubject = CurrentValueSubject<String?, Never>(nil)
    private let coinLogosSubject = CurrentValueSubject<[Int: String], Never>([:])
    
    // MARK: - Published AnyPublisher Properties
    
    /**
     * REACTIVE UI BINDING WITH ANYPUBLISHER
     * 
     * These AnyPublisher properties provide the same functionality as @Published
     * but give us more control over publishing behavior and transformations
     */
    
    var searchText: AnyPublisher<String, Never> {
        searchTextSubject.eraseToAnyPublisher()
    }
    
    var searchResults: AnyPublisher<[Coin], Never> {
        searchResultsSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    var errorMessage: AnyPublisher<String?, Never> {
        errorMessageSubject.eraseToAnyPublisher()
    }
    
    var coinLogos: AnyPublisher<[Int: String], Never> {
        coinLogosSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Popular Coins Publishers
    
    private let popularCoinsSubject = CurrentValueSubject<[Coin], Never>([])
    private let popularCoinsStateSubject = CurrentValueSubject<PopularCoinsState, Never>(.defaultState)
    
    var popularCoins: AnyPublisher<[Coin], Never> {
        popularCoinsSubject.eraseToAnyPublisher()
    }
    
    var popularCoinsState: AnyPublisher<PopularCoinsState, Never> {
        popularCoinsStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Current Value Accessors (For Internal Logic and ViewController Access)
    
    /**
     * INTERNAL STATE ACCESS
     * 
     * These computed properties provide access to current values
     * for both internal logic and ViewController access
     */
    
    private var currentSearchText: String {
        searchTextSubject.value
    }
    
    var currentSearchResults: [Coin] {
        searchResultsSubject.value
    }
    
    var currentCoinLogos: [Int: String] {
        coinLogosSubject.value
    }
    
    var currentPopularCoins: [Coin] {
        popularCoinsSubject.value
    }
    
    var currentPopularCoinsState: PopularCoinsState {
        popularCoinsStateSubject.value
    }
    
    // MARK: - Public Properties for Cache Access
    
    /**
     * Access to cached coin data for improved recent search functionality
     */
    var cachedCoins: [Coin] {
        return allCoins
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var apiRequestCancellables = Set<AnyCancellable>() // Separate cancellables for API requests
    private let coinManager: CoinManagerProtocol
    private let sharedCoinDataManager: SharedCoinDataManagerProtocol
    private let persistenceService: PersistenceServiceProtocol
    private var allCoins: [Coin] = []
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    // MARK: - Popular Coins Caching
    
    private var cachedPopularCoinsData: [Coin] = []
    private var popularCoinsCacheTimestamp: Date?
    private let popularCoinsCacheInterval: TimeInterval = 300 // 5 minutes cache
    
    // MARK: - Search Configuration
    
    private let maxSearchResults = 50 // Limit results for performance
    private let minimumSearchLength = 1 // Start searching after 1 character
    
    // MARK: - Lifecycle Management
    
    func cancelAllRequests() {
        // Cancel only API request subscriptions, NOT the core search functionality
        apiRequestCancellables.removeAll()
        
        // Reset loading state
        isLoadingSubject.send(false)
        
        AppLogger.performance("SearchVM: Cancelled API requests (keeping search functionality intact)")
    }
    
    // MARK: - Init
    
    // MARK: - Dependency Injection Initializer
    
    /**
     * DEPENDENCY INJECTION CONSTRUCTOR
     * 
     * Accepts CoinManagerProtocol for better testability and modularity.
     * Falls back to default CoinManager for backward compatibility.
     */
    init(coinManager: CoinManagerProtocol, sharedCoinDataManager: SharedCoinDataManagerProtocol, persistenceService: PersistenceServiceProtocol) {
        self.coinManager = coinManager
        self.sharedCoinDataManager = sharedCoinDataManager
        self.persistenceService = persistenceService
        setupSearchDebounce()
        loadInitialData()
        setupCacheUpdateListener()
        setupSharedCoinDataListener()
    }
    
    // MARK: - Cache Update Listener
    
    /**
     * CACHE UPDATE LISTENER
     * 
     * Listens for notifications when the main coin list updates the cache
     * and refreshes search data accordingly.
     */
    private func setupCacheUpdateListener() {
        NotificationCenter.default.publisher(for: .coinListCacheUpdated)
            .sink { [weak self] _ in
                AppLogger.search("Search: Received cache update notification")
                self?.refreshSearchData()
            }
            .store(in: &cancellables)
    }
    
    /**
     * SHARED COIN DATA LISTENER
     * 
     * Listens to SharedCoinDataManager for fresh price updates
     * and refreshes search results with updated data.
     * Does NOT invalidate popular coins cache if it's still valid.
     */
    private func setupSharedCoinDataListener() {
        sharedCoinDataManager.allCoins
            .receive(on: DispatchQueue.main)
            .sink { [weak self] freshCoins in
                guard let self = self else { return }
                
                // Only update if we have search results to refresh
                guard !self.currentSearchResults.isEmpty || !self.currentPopularCoins.isEmpty else { return }
                
                AppLogger.search("Search: Received fresh coin data from SharedCoinDataManager - updating search results")
                
                // Re-perform current search to merge fresh prices
                self.performSearch(for: self.currentSearchText)
                
                // For popular coins: Only refresh if cache is invalid, otherwise let cache handle it
                if !self.isPopularCoinsCacheValid {
                    AppLogger.cache("Popular Coins: Cache expired - refreshing with SharedCoinDataManager data")
                    self.fetchFreshPopularCoins(for: self.currentPopularCoinsState.selectedFilter)
                } else {
                    AppLogger.cache("Popular Coins: Cache still valid - skipping refresh from SharedCoinDataManager")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Setup
    
    /**
     * COMBINE DEBOUNCE IMPLEMENTATION
     * 
     * This sets up reactive search with debouncing to prevent excessive filtering.
     * - Debounces user input by 300ms
     * - Filters results on background queue
     * - Updates UI on main queue
     */
    private func setupSearchDebounce() {
        searchTextSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // Direct value instead of conversion
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(for: searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    /**
     * INITIAL DATA LOADING
     * 
     * Uses only cached data for search to avoid interfering with main coin list pagination.
     * For popular coins, fetches fresh data separately.
     */
    private func loadInitialData() {
        // Only use cached data for search functionality - no background fetching to avoid pagination conflicts
        if let cachedCoins = persistenceService.loadCoinList() {
            AppLogger.search("Search: Loaded \(cachedCoins.count) coins from cache for search")
            self.allCoins = cachedCoins
            
            // Load cached logos
            if let cachedLogos = persistenceService.loadCoinLogos() {
                coinLogosSubject.send(cachedLogos)
            }
        } else {
            AppLogger.search("Search: No cached coins available - search will be empty until main list loads data", level: .warning)
            self.allCoins = []
        }
        
        // Clear popular coins initially and load fresh data separately
        popularCoinsSubject.send([])  // Ensure no cached data is shown
        fetchFreshPopularCoins(for: currentPopularCoinsState.selectedFilter)
    }
    
        // MARK: - Removed Methods
    // fetchAllCoinsForSearch() and fetchCoinLogos() methods removed to prevent 
    // API conflicts with main coin list pagination
    
    // MARK: - Search Implementation
    
    /**
     * CORE SEARCH FUNCTIONALITY
     * 
     * Performs local search filtering with the following features:
     * - Case-insensitive matching with prefix priority
     * - Searches across name, symbol, and slug
     * - Input validation and sanitization
     * - Results limited for performance
     * - Sorted by market cap (most relevant first)
     * - Uses only cached data to avoid API conflicts
     */
    private func performSearch(for searchText: String) {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Input validation - clear results for empty or too short search
        guard !trimmedText.isEmpty && trimmedText.count >= minimumSearchLength else {
            searchResultsSubject.send([])
            return
        }
        
        // Prevent search for just whitespace or special characters
        guard trimmedText.rangeOfCharacter(from: .alphanumerics) != nil else {
            searchResultsSubject.send([])
            return
        }
        
        AppLogger.search("Search: Searching for '\(trimmedText)' in \(allCoins.count) cached coins")
        
        // Perform filtering on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Use optimized search matching
            let filteredCoins = self.allCoins.filter { coin in
                self.matchesCoin(coin, searchText: trimmedText)
            }
            
            // 🌐 MERGE FRESH PRICES: Update search results with latest prices from SharedCoinDataManager
            let sharedCoins = sharedCoinDataManager.currentCoins
            let coinsWithFreshPrices = filteredCoins.map { searchCoin in
                // Try to find fresh data for this coin
                if let freshCoin = sharedCoins.first(where: { $0.id == searchCoin.id }) {
                    return freshCoin  // Use fresh coin with updated prices
                } else {
                    return searchCoin  // Fallback to cached coin
                }
            }
            
            // Sort by market cap (most relevant first) and limit results
            let sortedResults = coinsWithFreshPrices
                .sorted { coin1, coin2 in
                    let marketCap1 = coin1.quote?["USD"]?.marketCap ?? 0
                    let marketCap2 = coin2.quote?["USD"]?.marketCap ?? 0
                    return marketCap1 > marketCap2
                }
                .prefix(self.maxSearchResults)
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let results = Array(sortedResults)
                self.searchResultsSubject.send(results)
                
                // Count how many got fresh prices
                let freshCount = results.filter { result in
                    sharedCoins.contains { $0.id == result.id }
                }.count
                
                AppLogger.search("Search: Found \(results.count) results for '\(trimmedText)' (\(freshCount) with fresh prices)")
                
                // Fetch missing logos for search results
                self.fetchLogosIfNeeded(for: results)
            }
        }
    }
    
    /**
     * EFFICIENT STRING SEARCH
     * 
     * Optimized search logic with prefix matching for better performance
     * Prioritizes exact matches and symbol matches over name matches
     */
    private func matchesCoin(_ coin: Coin, searchText: String) -> Bool {
        let search = searchText.lowercased()
        let symbolLower = coin.symbol.lowercased()
        let nameLower = coin.name.lowercased()
        
        // Exact symbol match (highest priority)
        if symbolLower == search {
            return true
        }
        
        // Symbol prefix match (high priority for tickers)
        if symbolLower.hasPrefix(search) {
            return true
        }
        
        // Name prefix match (good for "Bitcoin" → "Bit")
        if nameLower.hasPrefix(search) {
            return true
        }
        
        // Symbol contains (medium priority)
        if symbolLower.contains(search) {
            return true
        }
        
        // Name contains (lower priority)
        if nameLower.contains(search) {
            return true
        }
        
        // Slug matching (if available)
        if let slug = coin.slug?.lowercased() {
            if slug == search || slug.hasPrefix(search) || slug.contains(search) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Popular Coins Implementation
    
    /**
     * POPULAR COINS FILTERING LOGIC - REMOVED
     * 
     * This method has been replaced by fetchFreshPopularCoins() and calculatePopularCoins()
     * which use fresh API data instead of cached data for accurate gainers/losers.
     */
    // updatePopularCoins() method removed - now using fetchFreshPopularCoins() for fresh data
    
    // MARK: - Public Methods
    
    /**
     * MANUAL SEARCH TRIGGER
     * 
     * Allows manual triggering of search (useful for initial load or refresh)
     */
    func triggerSearch() {
        performSearch(for: currentSearchText)
    }
    
    /**
     * UPDATE POPULAR COINS FILTER
     * 
     * Updates the popular coins filter and uses cached data if available,
     * otherwise fetches fresh data. Cache expires after 5 minutes.
     */
    func updatePopularCoinsFilter(_ filter: PopularCoinsFilter) {
        let newState = PopularCoinsState(selectedFilter: filter)
        popularCoinsStateSubject.send(newState)
        
        // Check if we have valid cached data
        if let cacheTime = popularCoinsCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < popularCoinsCacheInterval,
           !cachedPopularCoinsData.isEmpty {
            
            // Use cached data immediately - no loading state needed
            print("🎯 Popular Coins: Using cached data instantly (age: \(Int(Date().timeIntervalSince(cacheTime)))s)")
            calculatePopularCoins(from: cachedPopularCoinsData, filter: filter)
            
        } else {
            // Cache expired or empty - fetch fresh data with loading state
            print("💰 Popular Coins: Cache expired or empty - fetching fresh data")
            fetchFreshPopularCoins(for: filter)
        }
    }
    
    /**
     * FETCH FRESH POPULAR COINS DATA
     * 
     * Fetches fresh data specifically for gainers/losers calculations
     */
    func fetchFreshPopularCoins(for filter: PopularCoinsFilter) {
        print("🌟 Popular Coins: Fetching fresh data for \(filter.displayName)")
        
        // Clear existing data immediately to prevent showing cached data
        popularCoinsSubject.send([])
        isLoadingSubject.send(true)
        
        // Fetch optimized dataset - reduced from 2000 to 500 to save API credits (3 credits vs 10)
        coinManager.getTopCoins(
            limit: 500,  // Reduced from 2000 - still plenty for volatile gainers/losers (3 credits vs 10)
            convert: "USD",
            start: 1,
            sortType: "market_cap",
            sortDir: "desc",
            priority: .normal
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoadingSubject.send(false)
                if case .failure(let error) = completion {
                    print("❌ Popular Coins: Failed to fetch fresh data: \(error)")
                    // Don't fallback to cached data - keep empty to avoid showing stale data
                    self?.popularCoinsSubject.send([])
                }
            },
            receiveValue: { [weak self] freshCoins in
                guard let self = self else { return }
                print("🌟 Popular Coins: Received \(freshCoins.count) fresh coins")
                
                // Cache the fresh data with timestamp
                self.cachedPopularCoinsData = freshCoins
                self.popularCoinsCacheTimestamp = Date()
                print("💾 Popular Coins: Cached data for 5 minutes")
                
                // Use fresh data for popular coins calculation
                self.calculatePopularCoins(from: freshCoins, filter: filter)
            }
        )
        .store(in: &apiRequestCancellables)
    }
    
    /**
     * CALCULATE POPULAR COINS FROM FRESH DATA
     */
    private func calculatePopularCoins(from freshCoins: [Coin], filter: PopularCoinsFilter) {
        print("🌟 Popular Coins: Calculating \(filter.displayName) from \(freshCoins.count) fresh coins")
        
        // Perform filtering on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Apply filtering criteria to fresh data
            let eligibleCoins = freshCoins.filter { coin in
                return coin.meetsPopularCoinsCriteria
            }
            
            print("🌟 Popular Coins: Found \(eligibleCoins.count) eligible coins from fresh data")
            
            // Sort and filter based on selected filter
            let filteredCoins: [Coin]
            switch filter {
            case .topGainers:
                let positiveCoins = eligibleCoins.filter { coin in
                    let change = coin.percentChange24hValue
                    return change > 0 // Only positive changes
                }
                print("🌟 Popular Coins: Found \(positiveCoins.count) coins with positive changes from fresh data")
                
                filteredCoins = positiveCoins
                    .sorted { coin1, coin2 in
                        // Sort by highest percentage gain first
                        coin1.percentChange24hValue > coin2.percentChange24hValue
                    }
                    .prefix(10) // Top 10 gainers
                    .map { $0 }
                
            case .topLosers:
                let negativeCoins = eligibleCoins.filter { coin in
                    let change = coin.percentChange24hValue
                    return change < 0 // Only negative changes
                }
                print("🌟 Popular Coins: Found \(negativeCoins.count) coins with negative changes from fresh data")
                
                filteredCoins = negativeCoins
                    .sorted { coin1, coin2 in
                        // Sort by lowest percentage change first (most negative)
                        coin1.percentChange24hValue < coin2.percentChange24hValue
                    }
                    .prefix(10) // Top 10 losers
                    .map { $0 }
            }
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.popularCoinsSubject.send(filteredCoins)
                
                print("🌟 Popular Coins: Updated UI with \(filteredCoins.count) fresh \(filter.displayName.lowercased())")
                
                // Fetch missing logos for popular coins
                self.fetchLogosIfNeeded(for: filteredCoins)
            }
        }
    }
    
    /**
     * CLEAR SEARCH
     * 
     * Clears search text and results
     */
    func clearSearch() {
        searchTextSubject.send("")
        searchResultsSubject.send([])
    }
    
    /**
     * UPDATE SEARCH TEXT
     * 
     * Updates the search text which will trigger debounced search
     */
    func updateSearchText(_ text: String) {
        searchTextSubject.send(text)
    }
    
    /**
     * REFRESH SEARCH DATA
     * 
     * Updates search data from current cache without making API calls.
     * Call this method when the main coin list has loaded fresh data.
     */
    func refreshSearchData() {
        // Only refresh from cache to avoid API conflicts
        if let cachedCoins = persistenceService.loadCoinList() {
            print("🔍 Search: Refreshed \(cachedCoins.count) coins from cache")
            self.allCoins = cachedCoins
            
            // Load updated logos
            if let cachedLogos = persistenceService.loadCoinLogos() {
                coinLogosSubject.send(cachedLogos)
            }
            
            // Re-perform current search with refreshed data
            performSearch(for: currentSearchText)
            
            // Use fresh data for popular coins instead of cached data
            fetchFreshPopularCoins(for: currentPopularCoinsState.selectedFilter)
            
            // Also fetch logos for any existing search results
            let existingResults = currentSearchResults
            if !existingResults.isEmpty {
                fetchLogosIfNeeded(for: existingResults)
            }
        } else {
            print("🔍 Search: No cached data available for refresh")
            self.allCoins = []
            searchResultsSubject.send([])
            popularCoinsSubject.send([])
        }
    }
    
    // MARK: - Logo Management
    
    /**
     * FETCH MISSING LOGOS FOR SEARCH RESULTS
     * 
     * Fetches logos for coins that appear in search results but don't have cached logos.
     * Uses low priority to avoid interfering with main data requests.
     */
    private func fetchLogosIfNeeded(for coins: [Coin]) {
        // Filter out coins that already have logos cached
        let coinsNeedingLogos = coins.filter { coin in
            currentCoinLogos[coin.id] == nil
        }
        
        guard !coinsNeedingLogos.isEmpty else {
            print("🔍 Search: All \(coins.count) result logos already cached")
            return
        }
        
        let coinIds = coinsNeedingLogos.map { $0.id }
        print("🔍 Search: Fetching \(coinIds.count) missing logos for search results")
        
        // Fetch missing logos with low priority - use API request cancellables
        coinManager.getCoinLogos(forIDs: coinIds, priority: .low)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLogos in
                guard let self = self else { return }
                
                print("🔍 Search: Received \(newLogos.count) new logos")
                
                // Merge new logos with existing cache
                let currentLogos = self.currentCoinLogos
                let mergedLogos = currentLogos.merging(newLogos) { _, new in new }
                self.coinLogosSubject.send(mergedLogos)
                
                // Update persistence cache with new logos
                self.persistenceService.saveCoinLogos(mergedLogos)
            }
            .store(in: &apiRequestCancellables) // Store in API-specific cancellables
    }
    
    /**
     * REFRESH POPULAR COINS CACHE
     * 
     * Forces a fresh fetch of popular coins data, bypassing cache
     */
    func refreshPopularCoinsCache() {
        print("🔄 Popular Coins: Manually refreshing cache")
        popularCoinsCacheTimestamp = nil // Invalidate cache
        fetchFreshPopularCoins(for: currentPopularCoinsState.selectedFilter)
    }
    
    /**
     * CHECK CACHE STATUS
     * 
     * Returns true if cache is valid and fresh
     */
    var isPopularCoinsCacheValid: Bool {
        guard let cacheTime = popularCoinsCacheTimestamp else { return false }
        return Date().timeIntervalSince(cacheTime) < popularCoinsCacheInterval && !cachedPopularCoinsData.isEmpty
    }
    
    // MARK: - Cleanup
    
    deinit {
        AppLogger.ui("SearchVM deinit - cleaning up all subscriptions")
        cancellables.removeAll() // Remove persistent search subscriptions
        apiRequestCancellables.removeAll() // Remove API request subscriptions
    }
} 