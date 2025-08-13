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
    private var cachedTopGainers: [Coin] = []  // Pre-calculated gainers
    private var cachedTopLosers: [Coin] = []   // Pre-calculated losers
    private var popularCoinsCacheTimestamp: Date?
    private let popularCoinsCacheInterval: TimeInterval = 300 // 5 minutes cache
    
    // MARK: - Search Configuration
    
    private let maxSearchResults = 50 // Limit results for performance
    private let minimumSearchLength = 1 // Start searching after 1 character
    private var isLoadingMoreForSearch = false // Prevent concurrent API calls for search
    
    // MARK: - Lifecycle Management
    
    func cancelAllRequests() {
        // Cancel only API request subscriptions, NOT the core search functionality
        apiRequestCancellables.removeAll()
        
        // Reset loading state
        isLoadingSubject.send(false)
        
        AppLogger.performance("SearchVM: Cancelled API requests (keeping search functionality intact)")
    }
    
    // MARK: - Error Handling
    
    /// Setup error handling for SharedCoinDataManager
    private func setupErrorHandling() {
        // 🚨 SUBSCRIBE TO SHARED ERRORS: Listen to errors from shared data manager
        sharedCoinDataManager.errors.sinkForUI(
            { [weak self] error in
                self?.handleSharedDataError(error)
            },
            storeIn: &cancellables
        )
    }
    
    /// Handle errors from SharedCoinDataManager
    private func handleSharedDataError(_ error: Error) {
        AppLogger.error("SearchVM: SharedCoinDataManager error", error: error)
        
        // Generate user-friendly error message using ErrorMessageProvider
        let retryInfo = ErrorMessageProvider.shared.getSearchRetryInfo(for: error)
        errorMessageSubject.send(retryInfo.message)
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
        setupErrorHandling()
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
        searchTextSubject.debounceForSearch(
            performSearch: { [weak self] searchText in
                self?.performSearch(for: searchText)
            },
            storeIn: &cancellables
        )
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
                
                // 🚀 HYBRID APPROACH: Smart API loading when no results found
                if results.isEmpty && trimmedText.count >= 2 && self.allCoins.count < 2000 {
                    AppLogger.search("Search: No results found for '\(trimmedText)' - attempting to load more coins via API")
                    self.loadMoreCoinsForSearch(searchText: trimmedText)
                } else {
                    // Fetch missing logos for search results
                    self.fetchLogosIfNeeded(for: results)
                }
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
        
        print("🔄 Popular Coins: Switching to \(filter.displayName)")
        print("🔄 Popular Coins: Cache timestamp: \(popularCoinsCacheTimestamp?.description ?? "nil")")
        print("🔄 Popular Coins: Raw cached data count: \(cachedPopularCoinsData.count)")
        print("🔄 Popular Coins: Pre-calculated gainers: \(cachedTopGainers.count), losers: \(cachedTopLosers.count)")
        
        // Check if we have valid pre-calculated cached data
        if let cacheTime = popularCoinsCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < popularCoinsCacheInterval,
           !cachedTopGainers.isEmpty && !cachedTopLosers.isEmpty {
            
            let cacheAge = Int(Date().timeIntervalSince(cacheTime))
            print("🎯 Popular Coins: Using pre-calculated \(filter.displayName) instantly (age: \(cacheAge)s)")
            
            // Use pre-calculated results instantly
            let cachedResults = filter == .topGainers ? cachedTopGainers : cachedTopLosers
            popularCoinsSubject.send(cachedResults)
            
            // Clear any error messages when using cached data
            errorMessageSubject.send(nil)
            
            fetchLogosIfNeeded(for: cachedResults)
            
        } else {
            let reason = popularCoinsCacheTimestamp == nil ? "no cache" : 
                        (cachedTopGainers.isEmpty || cachedTopLosers.isEmpty) ? "incomplete cache" : "cache expired"
            print("💰 Popular Coins: Cache invalid (\(reason)) - fetching fresh data for \(filter.displayName)")
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
        print("🌟 Popular Coins: Current loading state: \(isLoadingSubject.value)")
        print("🌟 Popular Coins: Current popular coins count: \(popularCoinsSubject.value.count)")
        
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
        .handleNetworkWithLoading(
            operation: "Popular Coins: Fetch fresh data",
            loadingSubject: isLoadingSubject,
            onSuccess: { [weak self] freshCoins in
                guard let self = self else { return }
                print("🌟 Popular Coins: Received \(freshCoins.count) fresh coins")
                
                // Cache the fresh data with timestamp
                self.cachedPopularCoinsData = freshCoins
                self.popularCoinsCacheTimestamp = Date()
                print("💾 Popular Coins: Cached data for 5 minutes")
                
                // Use fresh data for popular coins calculation
                self.calculatePopularCoins(from: freshCoins, filter: filter)
            },
            onError: { [weak self] _ in
                // Don't fallback to cached data - keep empty to avoid showing stale data
                self?.popularCoinsSubject.send([])
            },
            storeIn: &apiRequestCancellables
        )
    }
    
    /**
     * CALCULATE POPULAR COINS FROM FRESH DATA
     */
    private func calculatePopularCoins(from freshCoins: [Coin], filter: PopularCoinsFilter) {
        let startTime = Date()
        print("🌟 Popular Coins: Pre-calculating BOTH gainers and losers from \(freshCoins.count) coins")
        
        // Perform filtering on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Apply filtering criteria to fresh data
            let eligibleCoins = freshCoins.filter { coin in
                return coin.meetsPopularCoinsCriteria
            }
            
            print("🌟 Popular Coins: Found \(eligibleCoins.count) eligible coins from fresh data")
            
            // Calculate BOTH gainers and losers at once for instant switching
            let positiveCoins = eligibleCoins.filter { coin in
                coin.percentChange24hValue > 0
            }
            
            let negativeCoins = eligibleCoins.filter { coin in
                coin.percentChange24hValue < 0
            }
            
            let topGainers = positiveCoins
                .sorted { coin1, coin2 in
                    coin1.percentChange24hValue > coin2.percentChange24hValue
                }
                .prefix(10)
                .map { $0 }
            
            let topLosers = negativeCoins
                .sorted { coin1, coin2 in
                    coin1.percentChange24hValue < coin2.percentChange24hValue
                }
                .prefix(10)
                .map { $0 }
            
            print("🌟 Popular Coins: Pre-calculated \(topGainers.count) gainers and \(topLosers.count) losers")
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Store pre-calculated results in cache
                self.cachedTopGainers = topGainers
                self.cachedTopLosers = topLosers
                
                // Send the requested filter's results
                let requestedResults = filter == .topGainers ? topGainers : topLosers
                self.popularCoinsSubject.send(requestedResults)
                
                // Clear any error messages when data loads successfully
                self.errorMessageSubject.send(nil)
                
                print("🌟 Popular Coins: ✅ Updated UI with \(requestedResults.count) \(filter.displayName.lowercased()) in \(String(format: "%.3f", processingTime))s")
                print("🌟 Popular Coins: 💾 Both gainers and losers cached for instant switching")
                
                // Pre-fetch logos for BOTH gainers and losers for instant switching
                let allCoinsToPreload = Array(Set(topGainers + topLosers)) // Remove duplicates
                print("🖼️ Popular Coins: Pre-loading logos for \(allCoinsToPreload.count) coins (both gainers & losers)")
                self.fetchLogosIfNeeded(for: allCoinsToPreload)
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
        print("🔍 Search: refreshSearchData() called - this will force fresh popular coins fetch!")
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
            
            // For popular coins, use pre-calculated cache if valid, otherwise fetch fresh
            print("🔍 Search: Checking if popular coins cache needs refresh...")
            if let cacheTime = popularCoinsCacheTimestamp,
               Date().timeIntervalSince(cacheTime) < popularCoinsCacheInterval,
               !cachedTopGainers.isEmpty && !cachedTopLosers.isEmpty {
                print("🔍 Search: Popular coins pre-calculated cache is still valid, keeping current data")
                // Cache is still valid, no need to fetch fresh data
            } else {
                print("🔍 Search: Popular coins cache expired or incomplete, fetching fresh data")
                fetchFreshPopularCoins(for: currentPopularCoinsState.selectedFilter)
            }
            
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
    
    /**
     * HYBRID SEARCH: LOAD MORE COINS FOR SEARCH
     * 
     * Loads additional coins via API when no search results found.
     * Uses separate pagination to avoid conflicts with main coin list.
     */
    private func loadMoreCoinsForSearch(searchText: String) {
        // Prevent multiple concurrent API calls
        guard !isLoadingMoreForSearch else { return }
        isLoadingMoreForSearch = true
        
        let startIndex = allCoins.count + 1
        AppLogger.search("Search: Loading more coins via API (start: \(startIndex)) for search term '\(searchText)'")
        
        // Use separate API call with lower priority to avoid conflicts
        coinManager.getTopCoins(
            limit: 500,  // Load substantial amount for better search coverage
            convert: "USD",
            start: startIndex,
            sortType: "market_cap",
            sortDir: "desc",
            priority: .normal  // Lower priority than main list
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoadingMoreForSearch = false
            if case .failure(let error) = completion {
                AppLogger.error("Search: Failed to load more coins for search", error: error)
            }
        } receiveValue: { [weak self] newCoins in
            guard let self = self else { return }
            
            AppLogger.search("Search: Loaded \(newCoins.count) additional coins for search")
            
            // Add new coins to search data
            self.allCoins.append(contentsOf: newCoins)
            
            // Re-perform search with expanded dataset
            self.performSearch(for: searchText)
            
            // Prefetch logos for new coins
            self.fetchLogosIfNeeded(for: newCoins)
        }
        .store(in: &cancellables)
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
        cachedTopGainers.removeAll()     // Clear pre-calculated cache
        cachedTopLosers.removeAll()      // Clear pre-calculated cache
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
